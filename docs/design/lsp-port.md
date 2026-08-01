---
title: LSP Port — the language server, in Ingle
nav_exclude: true
sitemap: false
description: "Port the C language server (src/lsp.c) into Ingle so `inglec --lsp` is served by the self-hosted compiler — the last step to zero C (G6)."
layout: default
---

# LSP Port — reimplement the language server in Ingle

The v1.1 / gate **G6** campaign of the OFI-224 cutover. B4 made `inglec` the self-hosted compiler and
positions M1–M3 gave its checker `file:line:col` diagnostics; this campaign ports the **language server**
(`src/lsp.c`, 2518 lines) into Ingle so the editor experience — hover, go-to-definition, completion,
rename, semantic tokens, the lot — is served by the self-hosted compiler. When it reaches parity, the
frozen `inglec-stage0` host can be archived and **no C frontend runs anywhere**. Karl ratified **full
parity** (2026-08-01): every provider the C LSP has, the Ingle LSP has.

## 1. The finding — it's a thin shell over one data structure

`src/lsp.c` is large but mostly protocol plumbing. The intelligence is **one table the type-checker builds
during `check.c`: the `SemanticIndex`** (`src/semindex.c`/`semindex.h`, 91 lines) — a position-keyed list
of resolved identifiers, each carrying its span, kind, rendered type, doc, and **definition site**. Six of
the ten providers are thin projections over `semindex_lookup(line, col)`. So the port is gated far more by
**compiler-data plumbing in `checker.ig`** than by the 2,518 lines of JSON-RPC.

Two things already exist in Ingle and give a big head start:
- **`std/json.ig`** (882 lines) — a full JSON parser + serializer. Replaces `src/json.c` outright.
- **Positioned diagnostics** (M1–M3) — `ck.check_report` already emits `file:line:col: error: msg`. This is
  the Phase-1 data source; turning it into live editor squiggles is nearly free.

## 2. The hard prerequisites

- **Transport (Phase 1 gate).** The self-hosted runtime can't yet (a) read an exact-N-byte body from stdin
  (`read_line` strips newlines + can't distinguish EOF from a blank line), or (b) flush stdout (an editor
  pipe is fully buffered → responses never arrive). **Fix: two new self-hosted natives** — `read_stdin(n)`
  (blocking byte-count read, "" = EOF) and `flush()` — added to the **runtime** (`runtime.c`/`vm.c`) + the
  self-hosted compiler's tables, like `min`/`max`/`exe_path`. This is *runtime* C, not frontend C — it does
  not reintroduce the frozen frontend.
- **The SemanticIndex (the campaign).** Building a `selfhost/semindex.ig` needs, in order:
  - **A — per-node positions.** Leaf identifiers, `.field` names, and call *arguments* carry no position
    today (only `Box<T>` wrappers, at statement granularity). This is the expression-precise-position work
    deferred from M3 — a parser + AST + `check_expr`-signature change.
  - **B — definition sites.** `Local` has no `def_line`/`def_col`; add them to `Local` + the fn/struct/
    field/method/enum tables.
  - **C — the recorders.** A `SemEntry` container + ~10 recorder helpers wired into ~57 checker sites
    (mirrors `check.c`'s `sem_record_*`). Depends on A + B. The bulk of the work.
  - **D — cross-module resolution.** The self-hosted checker is **single-file**; every imported/qualified
    symbol is currently `TY_INFER`. references / rename / cross-file go-to-definition need project-wide
    resolution the checker has *no foundation for today* — the largest unknown.
- **The prover (last, optional).** `prove.c` (465 lines, hand-rolled Fourier–Motzkin, no Z3) backs *only*
  the "✓ proved" inlay hints. A greenfield Ingle port; do it at the very end.

## 3. Integration

An **in-process `--lsp` branch in the dispatcher** (`selfhost/compile_c.ig`) — it already imports the
checker, so no exec hop and no second link. `build/inglec` (= `compile_c-self`) serves the LSP itself.
Editors need **zero changes**: VS Code and Zed just spawn `inglec --lsp` (`editors/vscode/extension.js`,
`editors/zed/src/lib.rs`). The flip from stage0 to self-hosted only lands at **parity** — a partial LSP
would regress what stage0 already gives, so stage0 stays the `--lsp` host until the port is complete.

## 4. The phased plan

| Phase | Providers / scope | Gated on | Est. Ingle LOC |
|---|---|---|---|
| **1 — Skeleton + diagnostics** | transport loop, `initialize`/`shutdown`, doc store, didOpen/Change/Close → `publishDiagnostics` (reuses M1–M3 + std/json) | the 2 transport natives | ~400–600 |
| **2 — Cheap providers** | documentSymbol, codeAction, global completion, signatureHelp (free fns) — today's AST only | — | ~250–350 |
| **3 — The SemanticIndex** | per-node positions (A) + def-sites (B) + recorders (C) → `selfhost/semindex.ig` | A + B | ~400–600 |
| **4 — hover / definition / semanticTokens** | thin projections over the index | Phase 3 | ~400–600 |
| **5 — member completion / signatureHelp** | index-backed receiver-type resolution | Phase 3 | ~300–400 |
| **6 — references / rename** | project-wide file walk + cross-module resolution (D) | Phase 3 + D | ~500–700 |
| **7 — inlayHint (+ prover)** | inferred-type hints; then the prover port for verdicts | index; prover | ~200 + ~465 |

Full parity ≈ **3,000–3,700 Ingle lines + the 465-line prover** (vs `lsp.c` 2,518 + `prove.c` 465 +
`semindex.c`/`typefmt.c`/`diag.c`; `json.c`/`jsonw.c` drop out). First shippable slice = **Phase 1**.

## 5. Progress log

- **2026-08-01 — Campaign opened; scoped (5-agent recon); full parity ratified (Karl).** Plan above. Next:
  Phase 1 — the `read_stdin`/`flush` transport natives, then `selfhost/lsp.ig` (JSON-RPC loop + diagnostics).
