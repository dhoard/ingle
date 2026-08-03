#!/bin/sh
# tests/run-lsp-self.sh — regression harness for the SELF-HOSTED language server (inglec --lsp-self).
#
# The v1.1 LSP port, served IN-PROCESS by the self-hosted compiler (selfhost/lsp.ig), as opposed to
# run-lsp.sh which drives the frozen C host (inglec-stage0 --lsp). A tiny Python driver frames the messages
# and asserts the protocol responses (Python is a TEST dependency only). Run via `make test-lsp-self`.
# Phase 1: initialize/shutdown/exit, the document store, didOpen/didChange/didClose → publishDiagnostics.
# Phase 2: documentSymbol, completion (global + member-defer), signatureHelp, codeAction — over the AST/tokens.

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
def req(i, m, p): return {"jsonrpc":"2.0","id":i,"method":m,"params":p}

BAD  = 'fn main() {\n    let x: int = "hi"\n}\n'   # a type error at line 2 (0-based line 1), col 18 (0-based char 17)
GOOD = 'fn main() {\n    let x: int = 5\n}\n'
BAD2 = 'fn main() {\n    let y: bool = 99\n}\n'

# A rich doc for the Phase-2 providers (a struct with a field + method, an enum, two free fns).
P2 = ('struct Point {\n'
      '    x: int\n'
      '    fn scale(self, k: int) -> int {\n'
      '        return self.x + k\n'
      '    }\n'
      '}\n'
      '\n'
      'enum Shape {\n'
      '    Circle(r: int)\n'
      '}\n'
      '\n'
      'fn add(a: int, b: int) -> int {\n'
      '    return a + b\n'
      '}\n'
      '\n'
      'fn main() -> int {\n'
      '    let r = add(1, 2)\n'
      '    return r\n'
      '}\n'
      'fn use_point(p: Point) -> int {\n'
      '    return p.x\n'
      '}\n')
P2URI = "file:///tmp/ingle_lsp_self_p2.ig"
def p2open(): return {"jsonrpc":"2.0","method":"textDocument/didOpen","params":{"textDocument":{"uri":P2URI,"text":P2}}}
def p2req(i, m, extra):
    p = {"textDocument":{"uri":P2URI}}; p.update(extra); return req(i, m, p)

msgs = [
    req(1, "initialize", {}),
    didopen(BAD),
    didchange(GOOD),
    didchange(BAD2),
    didclose(),
    req(9, "textDocument/hover", {}),                       # unknown request → result null
    # Phase 2
    p2open(),
    p2req(20, "textDocument/documentSymbol", {}),
    p2req(21, "textDocument/completion", {"position":{"line":16,"character":4}}),   # global (in main body)
    p2req(22, "textDocument/completion", {"position":{"line":3,"character":20}}),   # member: right after "self." on the return line
    p2req(23, "textDocument/signatureHelp", {"position":{"line":16,"character":19}}), # inside add(1, |2)
    p2req(24, "textDocument/codeAction", {"range":{"start":{"line":16,"character":4},"end":{"line":16,"character":4}},"context":{"diagnostics":[]}}),
    # Phase 3: hover on a USE of the local `r` (line 17 `    return r` — `r` at char 11), definition of the `add` call (char 12)
    p2req(25, "textDocument/hover", {"position":{"line":17,"character":11}}),
    p2req(26, "textDocument/definition", {"position":{"line":16,"character":12}}),
    # member completion at `p.|` in `    return p.x` (line 20, char 13 = right after the dot)
    p2req(27, "textDocument/completion", {"position":{"line":20,"character":13}}),
    {"jsonrpc":"2.0","method":"exit"},
]
# A malformed JSON frame after initialize must be tolerated (the server keeps going).
data = frame(msgs[0]) + b"Content-Length: 5\r\n\r\n{bad!" + b"".join(frame(m) for m in msgs[1:])

p = subprocess.run([os.environ["BIN"], "--lsp-self"], input=data, capture_output=True, timeout=30)
out = p.stdout

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
by_id = {r["id"]: r for r in responses if "id" in r}

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

# ---- Phase 1 --------------------------------------------------------------------------------------
caps = by_id.get(1, {}).get("result", {}).get("capabilities", {})
check(caps.get("textDocumentSync") == 1 and caps.get("documentSymbolProvider") is True
      and caps.get("completionProvider") and caps.get("signatureHelpProvider") and caps.get("codeActionProvider") is True,
      "initialize → Phase-1+2 capabilities advertised")

diags = [r["params"]["diagnostics"] for r in responses
         if r.get("method") == "textDocument/publishDiagnostics" and r["params"]["uri"] == URI]
check([len(d) for d in diags] == [1, 0, 1, 0],
      f"publishDiagnostics open/change/change/close = 1,0,1,0 (got {[len(d) for d in diags]})")
if diags and len(diags[0]) == 1:
    st = diags[0][0]["range"]["start"]
    check(st["line"] == 1 and st["character"] == 17 and diags[0][0]["severity"] == 1 and diags[0][0]["source"] == "inglec",
          "first diagnostic 0-based range/severity/source")
else:
    check(False, "first diagnostic present")
check(by_id.get(9, {}).get("result", "x") is None, "unknown request → result null")

# ---- Phase 2 --------------------------------------------------------------------------------------
syms = by_id.get(20, {}).get("result", [])
def find_sym(ss, name):
    for s in ss:
        if s["name"] == name: return s
        r = find_sym(s.get("children", []), name)
        if r: return r
    return None
top = {s["name"]: s["kind"] for s in syms}
pt = find_sym(syms, "Point"); scale = find_sym(syms, "scale"); shape = find_sym(syms, "Shape")
check(top.get("Point") == 23 and top.get("Shape") == 10 and top.get("add") == 12 and top.get("main") == 12,
      "documentSymbol top-level kinds (struct23/enum10/fn12)")
check(pt is not None and any(c["name"] == "scale" and c["kind"] == 6 for c in pt.get("children", []))
      and any(c["name"] == "x" and c["kind"] == 8 for c in pt.get("children", [])),
      "documentSymbol struct children (field8 + method6)")
check(shape is not None and any(c["name"] == "Circle" and c["kind"] == 22 for c in shape.get("children", [])),
      "documentSymbol enum children (variant22)")
check(scale is not None and scale["range"]["start"]["line"] == 2, "method position from the AST (scale @ line 2)")

gc = by_id.get(21, {}).get("result", {}).get("items", [])
glabels = {it["label"]: it["kind"] for it in gc}
check(glabels.get("add") == 3 and glabels.get("Point") == 22 and glabels.get("Shape") == 13 and glabels.get("fn") == 14,
      "global completion (fn3/struct22/enum13 + keyword14)")
add_item = next((it for it in gc if it["label"] == "add"), {})
check(add_item.get("detail") == "fn add(a: int, b: int) -> int", "completion detail = full signature")
mc = by_id.get(22, {}).get("result", {}).get("items", None)
check(isinstance(mc, list) and len(mc) == 0, "member completion → empty (deferred to a later phase)")

sh = by_id.get(23, {}).get("result", {})
sig0 = sh.get("signatures", [{}])[0]
check(sig0.get("label") == "fn add(a: int, b: int) -> int" and len(sig0.get("parameters", [])) == 2
      and sh.get("activeParameter") == 1,
      "signatureHelp add(1,|2) → label + 2 params + activeParameter 1")

ca = by_id.get(24, {}).get("result", [])
titles = [a.get("title", "") for a in ca]
check(len(ca) == 2 and any("requires" in t for t in titles) and any("ensures" in t for t in titles)
      and all(a.get("kind") == "refactor.rewrite" and "edit" in a for a in ca),
      "codeAction → two contract scaffolds (refactor.rewrite edits)")

# ---- Phase 3 (SemanticIndex) ----------------------------------------------------------------------
hov = by_id.get(25, {}).get("result", {})
hval = hov.get("contents", {}).get("value", "") if hov else ""
check("let r" in hval and "int" in hval, f"hover on a local `r` → its inferred type (got {hval!r})")

dfn = by_id.get(26, {}).get("result", {})
check(isinstance(dfn, dict) and dfn.get("range", {}).get("start", {}).get("line") == 11,
      f"go-to-definition on the `add` call → fn add @ line 11 (got {dfn})")

mem = by_id.get(27, {}).get("result", {}).get("items", [])
mlabels = {it["label"]: it["kind"] for it in mem}
check(mlabels.get("x") == 5 and mlabels.get("scale") == 2 and len(mem) == 2,
      f"member completion `p.` → Point's field x (5) + method scale (2) (got {sorted(mlabels)})")

if fails:
    print(f"lsp-self: {fails} check(s) FAILED")
    sys.exit(1)
print("lsp-self: all Phase-1/2/3 checks passed (transport, diagnostics, symbols, completion, signatureHelp, codeAction, hover, definition)")
PY
