#!/bin/sh
# tests/run-compile-c-self.sh — smoke the CHECKED, FRONTEND-FREE self-hosted compiler (build/compile_c-self,
# from selfhost/compile_c.ig, built by the seed-built inglec-self — no src/ frontend anywhere in its build).
# This is the compiler OFI-224 G4 ships as the default `inglec`. The smoke proves two things a real user-facing
# compiler must do:
#   1. CHECK — reject a type-invalid program with exit 65 (stage-0's check-error code), and accept a valid one.
#   2. EMIT + RUN — compile every cgen_c_run fixture to a native binary that prints identically to the bytecode
#      VM oracle (build/inglec --emit=run). Reuses the curated cgen_c_run fixture set.
# Skipped gracefully if the binary or a C compiler is absent.
set -u
ROOT=$(cd "$(dirname "$0")/.." && pwd)
CC_SELF="$ROOT/build/compile_c-self"
VM="$ROOT/build/inglec"
LIB="$ROOT/build/libember_rt.a"

if [ ! -x "$CC_SELF" ]; then
    echo "SKIP    compile_c-self smoke — build/compile_c-self not built (run: make compile_c-self)"
    exit 0
fi
if ! command -v cc >/dev/null 2>&1; then
    echo "SKIP    compile_c-self smoke — no C compiler on PATH"
    exit 0
fi

pass=0
fail=0
tmpc="${TMPDIR:-/tmp}/ccself_$$.c"
tmpbin="${TMPDIR:-/tmp}/ccself_$$"

# 1. CHECK: a type error must be rejected with exit 65 (matching stage-0), a valid program accepted.
bad="${TMPDIR:-/tmp}/ccself_bad_$$.ig"
printf 'fn main() -> int {\n  let x: int = "no"\n  return 0\n}\n' > "$bad"
"$CC_SELF" "$bad" >/dev/null 2>&1
rc=$?
if [ "$rc" -eq 65 ]; then
    pass=$((pass + 1)); echo "PASS    compile_c-self rejects a type error (exit 65)"
else
    fail=$((fail + 1)); echo "FAIL    compile_c-self did not reject a type error (exit $rc, want 65)"
fi
rm -f "$bad"

# 2. EMIT + RUN: every cgen_c_run fixture must run identically to the VM.
for src in $(cd "$ROOT" && find tests/selfhost/cgen_c_run -name '*.ig' 2>/dev/null | sort); do
    want=$(cd "$ROOT" && "$VM" --emit=run "$src" 2>/dev/null | sed '/^=> 0$/d')
    if ! (cd "$ROOT" && "$CC_SELF" "$src" 2>/dev/null) | sed '/^=> 0$/d' > "$tmpc"; then
        fail=$((fail + 1)); echo "FAIL    compile_c-self did not emit C for $src"; continue
    fi
    if cc -std=c17 -O2 -D_DEFAULT_SOURCE -I"$ROOT/include" "$tmpc" "$LIB" -lm -o "$tmpbin" 2>/dev/null; then
        got=$("$tmpbin" 2>/dev/null | sed '/^=> 0$/d')
        if [ "$want" = "$got" ]; then
            pass=$((pass + 1))
        else
            fail=$((fail + 1)); echo "FAIL    compile_c-self output differs from the VM on $src"
        fi
    else
        fail=$((fail + 1)); echo "FAIL    compile_c-self C did not compile: $src"
    fi
    rm -f "$tmpc" "$tmpbin"
done

echo "compile_c-self smoke: $pass passed, $fail failed (frontend-free checked compiler)"
[ "$fail" -eq 0 ]
