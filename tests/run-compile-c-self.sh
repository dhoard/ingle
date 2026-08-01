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
# The C reference oracle is the FROZEN frontend (inglec-stage0), NOT build/inglec: post-cutover (OFI-224 B4)
# build/inglec IS the self-hosted compiler, so diffing against it would be self-vs-self (vacuously green).
VM="$ROOT/build/inglec-stage0"
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

# 1b. POSITIONED DIAGNOSTIC (positions M1): the reject must carry a `file:line: error: msg` — the self-hosted
#     checker's own source position, not the old generic "did not type-check". The error above is on line 2.
#     (These diagnostics are the self-hosted compiler's OWN, not golden-locked to stage-0 — post-B4 the
#     positioned goldens stay pinned to the frozen frontend — so this is where they are regression-guarded.)
badp="${TMPDIR:-/tmp}/ccself_badp_$$.ig"
printf 'fn main() -> int {\n  let x: int = "no"\n  return 0\n}\n' > "$badp"
dout=$("$CC_SELF" "$badp" 2>&1)
if printf '%s\n' "$dout" | grep -qE ':2: error: '; then
    pass=$((pass + 1)); echo "PASS    compile_c-self emits a positioned 'file:line: error:' diagnostic"
else
    fail=$((fail + 1)); echo "FAIL    compile_c-self diagnostic lacks a line position (got: $dout)"
fi
rm -f "$badp"

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

# 3. The `-o` DRIVER (Stage B1): one command must emit + cc-link + produce a runnable binary, finding the
#    runtime lib + headers relative to its own binary (no -I/-l from the caller). Run it from a NEUTRAL cwd so
#    the exe-relative lib/include/std resolution is what's exercised, not the repo cwd.
obin="${TMPDIR:-/tmp}/ccself_odrv_$$"
oprog="${TMPDIR:-/tmp}/ccself_odrv_$$.ig"
printf 'fn main() -> int {\n    println("o-driver ok")\n    return 0\n}\n' > "$oprog"
if (cd "${TMPDIR:-/tmp}" && "$CC_SELF" -o "$obin" "$oprog" >/dev/null 2>&1) && [ -x "$obin" ] && [ "$("$obin" 2>/dev/null | sed '/^=> 0$/d')" = "o-driver ok" ]; then
    pass=$((pass + 1)); echo "PASS    compile_c-self -o builds + runs a native binary in one command"
else
    fail=$((fail + 1)); echo "FAIL    compile_c-self -o did not build/run a native binary"
fi
rm -f "$obin" "$oprog"

# 4. The DISPATCHER's --emit=run (Stage B2): the self-hosted quick-run — compile to bytecode (inglec-emberc)
#    and exec the standalone runner (inglec-run), all frontend-free. Needs both binaries beside CC_SELF; run
#    from a neutral cwd so the exe-relative resolution of inglec-emberc / inglec-run / std is what's exercised.
rprog="${TMPDIR:-/tmp}/ccself_run_$$.ig"
printf 'fn main() -> int {\n    println("emit-run ok")\n    return 5\n}\n' > "$rprog"
if [ -x "$ROOT/build/inglec-emberc" ] && [ -x "$ROOT/build/inglec-run" ]; then
    got=$( (cd "${TMPDIR:-/tmp}" && "$CC_SELF" --emit=run "$rprog" 2>/dev/null) )
    want=$("$VM" --emit=run "$rprog" 2>/dev/null)
    if [ "$got" = "$want" ]; then
        pass=$((pass + 1)); echo "PASS    compile_c-self --emit=run == VM (self-hosted bytecode + standalone runner)"
    else
        fail=$((fail + 1)); echo "FAIL    compile_c-self --emit=run differs from the VM"
    fi
else
    echo "SKIP    --emit=run — build/inglec-emberc or build/inglec-run missing (run: make inglec-emberc runner)"
fi
rm -f "$rprog"

# 5. FROZEN-HOST routing (Stage B2/B3): a mode the self-hosted compiler doesn't implement (e.g. --emit=ast)
#    must be handed to build/inglec-stage0 — so its output equals the frozen frontend's. Skipped if stage0 isn't
#    built. (Run from a neutral cwd: the host is resolved relative to CC_SELF's binary, not the cwd.)
hprog="${TMPDIR:-/tmp}/ccself_host_$$.ig"
printf 'fn main() -> int {\n    return 0\n}\n' > "$hprog"
if [ -x "$ROOT/build/inglec-stage0" ]; then
    via=$( (cd "${TMPDIR:-/tmp}" && "$CC_SELF" --emit=ast "$hprog" 2>/dev/null) )
    direct=$("$ROOT/build/inglec-stage0" --emit=ast "$hprog" 2>/dev/null)
    if [ -n "$via" ] && [ "$via" = "$direct" ]; then
        pass=$((pass + 1)); echo "PASS    compile_c-self --emit=ast routes to the frozen host (== inglec-stage0)"
    else
        fail=$((fail + 1)); echo "FAIL    compile_c-self --emit=ast did not route to inglec-stage0"
    fi
else
    echo "SKIP    frozen-host routing — build/inglec-stage0 missing (run: make stage0)"
fi
rm -f "$hprog"

# 6. FLAVORED -o (Stage B5): `inglec -o` must AUTO-SELECT the runtime from the program. Concurrency → the
#    parallel runtime (runnable, deterministic → check == VM); graphics → the net+gfx runtime (needs raylib, so
#    compile+link only — no display). db/web/default are covered above / by cgen_c_run_db|web.
cprog=tests/run/nested_nursery.ig
if [ -f "$ROOT/build/libember_rt_par.a" ]; then
    if (cd "$ROOT" && "$CC_SELF" -o "$tmpbin" "$cprog" 2>/dev/null) && \
       [ "$("$tmpbin" 2>/dev/null | sed '/^=> 0$/d')" = "$("$VM" --emit=run "$cprog" 2>/dev/null | sed '/^=> 0$/d')" ]; then
        pass=$((pass + 1)); echo "PASS    compile_c-self -o auto-links the parallel runtime (concurrency == VM)"
    else
        fail=$((fail + 1)); echo "FAIL    compile_c-self -o concurrency (parallel runtime) differs from the VM"
    fi
    rm -f "$tmpbin"
fi
if [ -f "$ROOT/build/libember_rt_net_gfx.a" ]; then
    gprog=$(cd "$ROOT" && find examples/graphics -name '*.ig' 2>/dev/null | head -1)
    if [ -n "$gprog" ] && (cd "$ROOT" && "$CC_SELF" -o "$tmpbin" "$gprog" 2>/dev/null) && [ -x "$tmpbin" ]; then
        pass=$((pass + 1)); echo "PASS    compile_c-self -o auto-links the graphics runtime (compiles + links)"
    else
        fail=$((fail + 1)); echo "FAIL    compile_c-self -o graphics (net+gfx runtime) did not build"
    fi
    rm -f "$tmpbin"
fi

# 7. The min/max builtins (a self-hosting DOGFOOD feature added entirely in Ingle — the C frontend does not
#    know them, so the golden output is hardcoded rather than diffed against the stage-0 VM). Also checks a
#    USER fn of the same name still WINS (shadows the builtin).
mmprog="${TMPDIR:-/tmp}/ccself_mm_$$.ig"
printf 'fn max(a: int, b: int) -> int { return 999 }\nfn main() -> int {\n    println("min={min(3, 7)} max={max(3, 7)}")\n    println("user_max={max(3, 7)}")\n    return 0\n}\n' > "$mmprog"
if (cd "${TMPDIR:-/tmp}" && "$CC_SELF" -o "$tmpbin" "$mmprog" 2>/dev/null) && \
   [ "$("$tmpbin" 2>/dev/null | sed '/^=> 0$/d')" = "min=3 max=999
user_max=999" ]; then
    pass=$((pass + 1)); echo "PASS    compile_c-self min/max builtins work + a user fn shadows the builtin"
else
    fail=$((fail + 1)); echo "FAIL    compile_c-self min/max builtins / user-fn shadowing"
fi
rm -f "$mmprog" "$tmpbin"

echo "compile_c-self smoke: $pass passed, $fail failed (frontend-free checked compiler)"
[ "$fail" -eq 0 ]
