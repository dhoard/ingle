#!/bin/sh
# tests/run-lib.sh — library-mode regression (DSP Phase 1: `export "c"` + `inglec --emit=lib`).
#   tests/lib/<case>/lib.ig + host.c → `inglec --emit=lib -o lib.a`, link host.c, run; stdout must equal
#                                      tests/lib/<case>/expected.out
#   tests/lib/reject/<case>.ig       → must be REJECTED (exit 65) with exactly <case>.err on stdout+stderr
# The frozen stage-0 cannot parse `export`, so these run against the shipping self-hosted compiler only.
# Bless with: tests/run-lib.sh --update (eyeball the diff first).
ROOT=$(cd "$(dirname "$0")/.." && pwd)
SELF="$ROOT/build/inglec"
UPDATE=0
[ "${1:-}" = "--update" ] && UPDATE=1
command -v cc >/dev/null 2>&1 || { echo "lib: skipped (no cc)"; exit 0; }
pass=0; fail=0
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

for dir in "$ROOT"/tests/lib/*/; do
    case_name=$(basename "$dir")
    [ "$case_name" = "reject" ] && continue
    rel="tests/lib/$case_name"
    if ! (cd "$ROOT" && "$SELF" --emit=lib -o "$WORK/$case_name.a" "$rel/lib.ig" >"$WORK/build.log" 2>&1); then
        echo "FAIL    $rel  (library build failed)"; cat "$WORK/build.log"; fail=$((fail + 1)); continue
    fi
    if ! cc -std=c17 "$dir/host.c" "$WORK/$case_name.a" -lm -o "$WORK/$case_name.host" 2>"$WORK/link.log"; then
        echo "FAIL    $rel  (host link failed)"; cat "$WORK/link.log"; fail=$((fail + 1)); continue
    fi
    got=$("$WORK/$case_name.host" 2>&1)
    if [ "$UPDATE" -eq 1 ]; then
        printf '%s\n' "$got" > "$dir/expected.out"; echo "UPDATED $rel"; continue
    fi
    if [ "$got" = "$(cat "$dir/expected.out" 2>/dev/null)" ]; then
        echo "PASS    $rel  (C host == expected)"; pass=$((pass + 1))
    else
        echo "FAIL    $rel  (C host output differs)"; printf '%s\n' "$got" | diff "$dir/expected.out" - | head -20; fail=$((fail + 1))
    fi
done

for src in "$ROOT"/tests/lib/reject/*.ig; do
    [ -f "$src" ] || continue
    rel="tests/lib/reject/$(basename "$src")"
    got=$(cd "$ROOT" && "$SELF" --emit=lib "$rel" 2>&1)
    code=$?
    want="${src%.ig}.err"
    if [ "$UPDATE" -eq 1 ]; then
        printf '%s\n' "$got" > "$want"; echo "UPDATED $rel"; continue
    fi
    if [ "$code" -eq 65 ] && [ "$got" = "$(cat "$want" 2>/dev/null)" ]; then
        echo "PASS    $rel  (rejected as expected)"; pass=$((pass + 1))
    else
        echo "FAIL    $rel  (exit $code, or diagnostics differ)"; printf '%s\n' "$got" | diff "$want" - | head -20; fail=$((fail + 1))
    fi
done

echo "lib: passed $pass, failed $fail"
[ "$fail" -eq 0 ]
