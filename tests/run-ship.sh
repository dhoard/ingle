#!/bin/sh
# tests/run-ship.sh — golden behaviour corpus for the SHIPPING self-hosted compiler (build/inglec).
#   tests/ship/<case>.ig        → `inglec -o` AND `inglec --emit=run` must each print exactly <case>.out
#                                 (a file whose FIRST line contains "native-only" runs the -o path only)
#   tests/ship/reject/<case>.ig → `inglec -o` must REJECT it (exit 65) with exactly <case>.err
# This is the successor oracle for behaviour the frozen stage-0 gets WRONG (e.g. OFI-233), so it cannot sit in
# the stage-0-locked tests/run or tests/native differentials. Bless: tests/run-ship.sh --update (eyeball first).
ROOT=$(cd "$(dirname "$0")/.." && pwd)
SELF="$ROOT/build/inglec"
UPDATE=0
[ "${1:-}" = "--update" ] && UPDATE=1
pass=0; fail=0
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

for src in "$ROOT"/tests/ship/*.ig; do
    [ -f "$src" ] || continue
    rel="tests/ship/$(basename "$src")"
    want="${src%.ig}.out"
    bin="$WORK/$(basename "${src%.ig}")"
    if ! (cd "$ROOT" && "$SELF" -o "$bin" "$rel" >"$WORK/build.log" 2>&1); then
        echo "FAIL    $rel  (native compile failed)"; cat "$WORK/build.log"; fail=$((fail + 1)); continue
    fi
    got=$("$bin" 2>&1)
    if [ "$UPDATE" -eq 1 ]; then
        printf '%s\n' "$got" > "$want"; echo "UPDATED $rel"; continue
    fi
    if [ "$got" = "$(cat "$want" 2>/dev/null)" ]; then
        echo "PASS    $rel  (native == golden)"; pass=$((pass + 1))
    else
        echo "FAIL    $rel  (native differs from golden)"; printf '%s\n' "$got" | diff "$want" - | head -20; fail=$((fail + 1))
    fi
    if head -1 "$src" | grep -q "native-only"; then
        continue
    fi
    got=$(cd "$ROOT" && "$SELF" --emit=run "$rel" 2>&1)
    if [ "$got" = "$(cat "$want" 2>/dev/null)" ]; then
        echo "PASS    $rel  (--emit=run == golden)"; pass=$((pass + 1))
    else
        echo "FAIL    $rel  (--emit=run differs from golden)"; printf '%s\n' "$got" | diff "$want" - | head -20; fail=$((fail + 1))
    fi
done

for src in "$ROOT"/tests/ship/reject/*.ig; do
    [ -f "$src" ] || continue
    rel="tests/ship/reject/$(basename "$src")"
    want="${src%.ig}.err"
    got=$(cd "$ROOT" && "$SELF" -o "$WORK/rej" "$rel" 2>&1)
    code=$?
    if [ "$UPDATE" -eq 1 ]; then
        printf '%s\n' "$got" > "$want"; echo "UPDATED $rel"; continue
    fi
    if [ "$code" -eq 65 ] && [ "$got" = "$(cat "$want" 2>/dev/null)" ]; then
        echo "PASS    $rel  (rejected as expected)"; pass=$((pass + 1))
    else
        echo "FAIL    $rel  (exit $code, or diagnostics differ)"; printf '%s\n' "$got" | diff "$want" - | head -20; fail=$((fail + 1))
    fi
done

echo "ship: passed $pass, failed $fail"
[ "$fail" -eq 0 ]
