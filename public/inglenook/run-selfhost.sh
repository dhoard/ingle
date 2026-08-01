#!/bin/sh
# run-selfhost.sh — build + launch Inglenook compiled by the SELF-HOSTED compiler, the counterpart to
# run.sh (which runs it on the frontend VM). Post-cutover (OFI-224 B4) the default `inglec` IS the
# self-hosted compiler, so this is now a ONE-COMMAND native build: `inglec -o` checks the program, emits C
# through the self-hosted C-emit backend, AUTO-SELECTS the net+graphics runtime (raylib + libcurl, because
# ide.ig imports std/draw + std/ui) and links a standalone GUI binary — the manual --emit=c → cc → re-emit
# → link pipeline this script used pre-cutover is exactly what `inglec -o` now does in one step. Same
# runtime, same app, same pixels as run.sh — only the COMPILER that produced the binary differs.
#
# Usage: ANTHROPIC_API_KEY=sk-ant-... ./public/inglenook/run-selfhost.sh
#        (runs without a key too — pick Ollama in Settings, or sending just reminds you)
set -e
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
cd "$ROOT"

# 1. Build the self-hosted toolchain (the default `inglec` dispatcher) + the net+graphics runtime that
#    `inglec -o` auto-links, and the full frontend (inglec-net-gfx) the Verified Loop shells out to below.
make >/dev/null
make net-graphics >/dev/null

# 2. Compile Inglenook to a native binary in ONE command with the self-hosted compiler.
INGLE_STD="$ROOT/std" build/inglec -o build/inglenook-self public/inglenook/ide.ig

# The Verified Loop / linter / tape-scrubber shell out to a compiler using the frontend's positioned
# diagnostics + --emit=check (prover) + --faults=agent — which the self-hosted compiler does not provide
# yet — so point them at the full frontend (inglec-net-gfx). The Source panel shells out to `quog`.
: "${INGLENOOK_INGLEC:=$ROOT/build/inglec-net-gfx}"; export INGLENOOK_INGLEC
: "${EMBER_TAPE:=/tmp/inglenook.tape}"; export EMBER_TAPE
make quog >/dev/null 2>&1 || true
if [ -x "$ROOT/build/quog" ]; then : "${INGLENOOK_QUOG:=$ROOT/build/quog}"; export INGLENOOK_QUOG; fi

echo "Inglenook (self-hosted native build) — UI tape -> $EMBER_TAPE" >&2
exec build/inglenook-self
