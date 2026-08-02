#!/bin/sh
# tests/run-lsp-self.sh — regression harness for the SELF-HOSTED language server (inglec --lsp-self).
#
# The v1.1 LSP port, Phase 1: the JSON-RPC transport + live diagnostics served IN-PROCESS by the
# self-hosted compiler (selfhost/lsp.ig), as opposed to run-lsp.sh which drives the frozen C host
# (inglec-stage0 --lsp). A tiny Python driver frames the messages and asserts the protocol responses
# (Python is a TEST dependency only). Kept out of the dependency-free `make test`; run via `make test-lsp-self`.
# Covers Phase 1: initialize/shutdown/exit, the document store, and didOpen/didChange/didClose →
# publishDiagnostics off the self-hosted checker's positioned (M1-M3) diagnostics.

set -u
ROOT=$(cd "$(dirname "$0")/.." && pwd)
BIN="$ROOT/build/inglec"                 # the self-hosted dispatcher — it owns --lsp-self in-process

if [ ! -x "$BIN" ]; then
    echo "skip: $BIN not built — run 'make' first"
    exit 0
fi
if ! command -v python3 >/dev/null 2>&1; then
    echo "skip: python3 not found (the LSP test driver needs it)"
    exit 0
fi

BIN="$BIN" python3 - <<'PY'
import subprocess, json, os, sys

def frame(obj):
    b = json.dumps(obj).encode()
    return b"Content-Length: %d\r\n\r\n%s" % (len(b), b)

URI = "file:///tmp/ingle_lsp_self.ig"
def didopen(t):   return {"jsonrpc":"2.0","method":"textDocument/didOpen","params":{"textDocument":{"uri":URI,"text":t}}}
def didchange(t): return {"jsonrpc":"2.0","method":"textDocument/didChange","params":{"textDocument":{"uri":URI},"contentChanges":[{"text":t}]}}
def didclose():   return {"jsonrpc":"2.0","method":"textDocument/didClose","params":{"textDocument":{"uri":URI}}}

BAD  = 'fn main() {\n    let x: int = "hi"\n}\n'   # a type error at line 2 (0-based line 1), col 18 (0-based char 17)
GOOD = 'fn main() {\n    let x: int = 5\n}\n'
BAD2 = 'fn main() {\n    let y: bool = 99\n}\n'

msgs = [
    {"jsonrpc":"2.0","id":1,"method":"initialize","params":{}},
    didopen(BAD),
    didchange(GOOD),
    didchange(BAD2),
    didclose(),
    {"jsonrpc":"2.0","id":9,"method":"textDocument/hover","params":{}},  # unknown request → result null
    {"jsonrpc":"2.0","method":"exit"},
]
# A malformed JSON frame after initialize must be tolerated (the server keeps going).
data = frame(msgs[0]) + b"Content-Length: 5\r\n\r\n{bad!" + b"".join(frame(m) for m in msgs[1:])

p = subprocess.run([os.environ["BIN"], "--lsp-self"], input=data, capture_output=True, timeout=30)
out = p.stdout

# Decode the framed response stream.
responses = []
i = 0
while i < len(out):
    j = out.find(b"\r\n\r\n", i)
    if j < 0: break
    cl = None
    for line in out[i:j].decode(errors="replace").split("\r\n"):
        if line.lower().startswith("content-length:"):
            cl = int(line.split(":", 1)[1])
    if cl is None: break
    responses.append(json.loads(out[j+4:j+4+cl]))
    i = j+4+cl

fails = 0
def check(cond, label):
    global fails
    if cond:
        print(f"lsp-self: passed — {label}")
    else:
        print(f"lsp-self: FAIL — {label}")
        fails += 1

if p.returncode != 0:
    print(f"lsp-self: FAIL — process exit {p.returncode} (stderr={p.stderr[:200]!r})")
    fails += 1

init = [r for r in responses if r.get("id") == 1]
check(len(init) == 1 and init[0].get("result", {}).get("capabilities", {}).get("textDocumentSync") == 1,
      "initialize → capabilities (textDocumentSync:1)")

diags = [r["params"]["diagnostics"] for r in responses if r.get("method") == "textDocument/publishDiagnostics"]
# didOpen(BAD)=1, didChange(GOOD)=0, didChange(BAD2)=1, didClose=0
check([len(d) for d in diags] == [1, 0, 1, 0],
      f"publishDiagnostics sequence open/change/change/close = 1,0,1,0 (got {[len(d) for d in diags]})")

if diags and len(diags[0]) == 1:
    d0 = diags[0][0]
    st = d0["range"]["start"]
    check(st["line"] == 1 and st["character"] == 17 and d0["severity"] == 1 and d0["source"] == "inglec",
          f"first diagnostic 0-based range/severity/source (line={st['line']},char={st['character']})")
else:
    check(False, "first diagnostic present")

unk = [r for r in responses if r.get("id") == 9]
check(len(unk) == 1 and unk[0].get("result") is None, "unknown request → result null (client never hangs)")

if fails:
    print(f"lsp-self: {fails} check(s) FAILED")
    sys.exit(1)
print("lsp-self: all Phase-1 checks passed (transport + diagnostics + lifecycle)")
PY
