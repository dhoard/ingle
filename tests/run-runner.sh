#!/bin/sh
# tests/run-runner.sh — guard the standalone, FRONTEND-FREE bytecode runner (build/inglec-run, OFI-224 Stage B2).
# For a spread of default corpus programs: serialize a `.igb` (via the reference compiler's --emit=bytecode-bin),
# run it through the standalone runner, and require byte-identical stdout to the bytecode VM (--emit=run). Proves
# the runner — the KEPT VM + runtime with NO frontend linked — executes bytecode exactly as the full compiler's
# VM does, so `inglec --emit=run` can hand it compiled bytecode once the frontend retires. Skipped if the runner
# or the reference compiler is absent.
set -u
ROOT=$(cd "$(dirname "$0")/.." && pwd)
RUNNER="$ROOT/build/inglec-run"
# The reference VM is the FROZEN frontend (inglec-stage0): post-cutover (OFI-224 B4) build/inglec is the
# self-hosted dispatcher, so the "runner == reference VM" guarantee needs a stable C reference to hold.
REF="$ROOT/build/inglec-stage0"

if [ ! -x "$RUNNER" ] || [ ! -x "$REF" ]; then
    echo "SKIP    runner — build/inglec-run or build/inglec missing (run: make runner)"
    exit 0
fi

pass=0
fail=0
igb="${TMPDIR:-/tmp}/runner_$$.igb"
# The cgen_c_run fixtures are the curated small/fast/deterministic set — no stdin reads, no long loops, no
# flavored-runtime natives the default runner lacks — so the gate stays quick and reliable.
for src in $(cd "$ROOT" && find tests/selfhost/cgen_c_run -name '*.ig' 2>/dev/null | sort); do
    want=$(cd "$ROOT" && timeout 20 "$REF" --emit=run "$src" 2>/dev/null)
    if ! (cd "$ROOT" && "$REF" --emit=bytecode-bin -o "$igb" "$src" 2>/dev/null); then
        continue   # a program the reference can't serialize (needs a flavored build) — not the runner's concern
    fi
    got=$(timeout 20 "$RUNNER" "$igb" 2>/dev/null)
    if [ "$want" = "$got" ]; then
        pass=$((pass + 1))
    else
        fail=$((fail + 1)); echo "FAIL    standalone runner differs from the VM on $src"
    fi
done
rm -f "$igb"

echo "standalone runner: $pass ran identical to the VM, $fail differed (frontend-free .igb execution)"
[ "$fail" -eq 0 ]
