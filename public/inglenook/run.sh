#!/bin/sh
# Build the net+graphics compiler (libcurl + raylib) and run Inglenook from the repo root.
# Usage: ANTHROPIC_API_KEY=sk-ant-... ./public/inglenook/run.sh
#        (runs without a key too — pick Ollama in Settings, or sending just reminds you)
#
# Diagnostics: the UI TAPE is recorded to $EMBER_TAPE (default /tmp/inglenook.tape) — one JSON line
# per frame (input + every draw command + interaction events). `tail -f /tmp/inglenook.tape` while the
# app runs to watch it live, or read it after to see whether the render thread is alive (frames still
# advancing) vs frozen, and what state it's in. Set EMBER_TAPE= (empty) to turn it off (zero cost).
set -e
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
cd "$ROOT"
make net-graphics >/dev/null
: "${EMBER_TAPE:=/tmp/inglenook.tape}"
export EMBER_TAPE
# The Verified Loop / linter / tape-scrubber shell out to the compiler, using the frontend's positioned
# diagnostics, --emit=check (prover) and --faults=agent. Post-cutover (OFI-224 B4) the default `build/inglec`
# is the SELF-HOSTED dispatcher, which has none of those yet (it delegates them to inglec-stage0) — so point
# the loop at the full frontend we just built (inglec-net-gfx). Override with INGLENOOK_INGLEC=.
: "${INGLENOOK_INGLEC:=$ROOT/build/inglec-net-gfx}"
export INGLENOOK_INGLEC
# The Source panel shells out to the `quog` VCS (a sibling Ingle app). Build it and point the panel at
# it so it works without a separately-installed `quog` on PATH (override with INGLENOOK_QUOG=). Kept
# non-fatal: if the db build is unavailable, the panel just reports quog missing.
make quog >/dev/null 2>&1 || true
if [ -x "$ROOT/build/quog" ]; then
    : "${INGLENOOK_QUOG:=$ROOT/build/quog}"
    export INGLENOOK_QUOG
fi
echo "Inglenook: UI tape → $EMBER_TAPE   (tail -f it to watch; EMBER_TAPE= to disable)" >&2
exec build/inglec-net-gfx --emit=run public/inglenook/ide.ig
