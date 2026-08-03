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

- **2026-08-01 — Campaign opened; scoped (5-agent recon); full parity ratified (Karl).** Plan above.
- **2026-08-01 — Phase 1a DONE: the transport natives** (`74cee77`) — `read_stdin(n)` + `flush()`,
  self-hosted-only, both backends, gated. Plus a Makefile fix (`4fe6469`): the B4 flip had forward-referenced
  `$(BIN)`'s prerequisite vars, so a plain `make` silently reused STALE self-hosted binaries (it bit the
  positions + LSP work repeatedly) — hoisted the definitions above the rule.
- **2026-08-01 — Phase 1b BLOCKED on the return-typing frontier (OFI-173) → a campaign RE-SCOPE.** Wrote the
  JSON-RPC transport skeleton (`read_message`/`write_message`/`initialize` handshake) behind a `--lsp-self`
  dev flag — but it hit OFI-173 HARD, in the *transport itself*, not the Phase-3 index. The self-hosted
  C-emit resolves only a few string INTRINSICS (`.len`/`.split`/`.chars`/`.parse_int` + `char_code`);
  `.substring`/`.index_of`/`.slice` are `std/string` free functions it can't UFCS-resolve, and chaining
  `.split()[i].method()` is the "method-on-array-element" gap. `std/json` (needed for real message parsing)
  also fails to compile INTO the compiler — its `Parser`/`_escape` trip the same gap on `.chars()`/`self.cs`.
  Reverted the skeleton to keep the build green (`make test` 458/0). **THE FINDING: the LSP port is gated on
  the OFI-173 return-typing work far EARLIER than planned — the transport's own string handling needs it, not
  just the SemanticIndex. So the campaign's true first phase is the return-typing / OFI-174 completeness work
  in the self-hosted C-emit** — make a bound method/function/array-element result carry its type so a
  `.method()` on it resolves (the same plumbing the deferred expression-precise positions + the SemanticIndex
  need). Everything downstream — transport, `std/json`, the index, the providers — unblocks once it lands.
  This is a real compiler campaign of its own; **next: scope the return-typing work (size + approach).**
- **2026-08-02 — PHASE 1 DONE: the transport + live diagnostics, served in-process by `inglec --lsp-self`.**
  `selfhost/lsp.ig` (~330 lines): a Content-Length-framed stdio loop (the M1a `read_stdin`/`flush` natives),
  `initialize`/`shutdown`/`exit`, a full-sync document store, and didOpen/didChange/didClose →
  `textDocument/publishDiagnostics` off the self-hosted checker's positioned (M1–M3) diagnostics. Messages are
  parsed + built with **std/json**. Wired as a `--lsp-self` DEV branch in the dispatcher (`compile_c.ig`) BEFORE
  the frozen-host routing, so the shipping `--lsp` still goes to stage-0 until parity — no editor regression.
  Verified end-to-end (`tests/run-lsp-self.sh`, `make test-lsp-self`): initialize→capabilities, a type-error
  doc → one 0-based Diagnostic at the right range/severity/source, didChange clears then re-raises, didClose
  clears, an unknown request → `result:null`, a malformed JSON frame is tolerated, `exit`→clean. New checker
  entry point `check_diags(src, path) -> [string]` (the returned `[string]` is indexed cross-module in lsp.ig —
  the OFI-226 fix in action, and its FIRST use in the compiler's own source: the reproduction fixed point now
  exercises it, `make verify` all-9-green). THREE compiler gaps surfaced + handled: **OFI-226** (fixed — the
  return-element typing that unblocked the diag path); **OFI-227** (a cross-module same-named struct collision —
  std/json's `Parser` vs parser.ig's — worked around by renaming json's internal `Parser`→`JsonParser`);
  **OFI-228** (`return c.diags` of an owned field of a dropped local corrupts it — worked around with `.clone()`).
  KNOWN Phase-1 limitations (documented, not silent): only CHECK diagnostics (the self-hosted parser
  best-effort-recovers rather than positioning SYNTAX errors — a follow-on); single-module (imports are lenient,
  no cross-file resolution — the Phase-3 SemanticIndex); utf-8 position encoding only (byte columns pass through;
  utf-16 negotiation deferred); a minimal 1-column diagnostic range (real token spans deferred). **NEXT = Phase 2:
  the cheap providers (documentSymbol, codeAction, global completion, signatureHelp) over today's AST.**
- **2026-08-02 — PHASE 2 DONE: the AST/token providers — documentSymbol, completion, signatureHelp, codeAction.**
  Added to `selfhost/lsp.ig`, all driven by `ps.parse` + `lx.lex` of the doc text (both best-effort on malformed
  input). **documentSymbol**: a hierarchical DocumentSymbol[] — fn(12), struct(23) with field(8)+method(6)
  children, enum(10) with variant(22) children, interface(11), let(13). Positions come from `FnDecl.line/col`
  (fns + methods) and, for struct/enum/interface/let (which the AST doesn't position), a brace-depth-0 token scan
  for `<keyword> <name>` (fields/variants reuse the parent's position, as the C server does). **completion**:
  global items (every named top-level decl with a kind + signature detail, then the 31 keywords, kind 14) — the
  member-vs-global split is lexical (`receiver.|` → empty items, deferred). **signatureHelp**: walks left from the
  cursor to the enclosing `(` (bracket-depth tracking + comma count → activeParameter), resolves a FREE-fn callee
  by name, emits the signature label + per-user-param labels (self skipped; member/builtin → null). **codeAction**:
  the two contract scaffolds (`requires`/`ensures`, refactor.rewrite WorkspaceEdits inserting a clause before a
  top-level fn's body `{`). KEY enabler: `lx.kind_name(...)` (a stable string like "IDENT"/"LPAREN") for all token
  comparisons — lsp.ig cannot `match` the lexer's `Tk` variants across the module boundary. Gated: `tests/run-lsp-self.sh`
  grew 9 Phase-2 assertions (13 total, `make test-lsp-self`). `make verify` all-9-green, selfhost 1822/0,
  reproduction fixed point intact, NO reseed. KNOWN Phase-2 limits: the struct/enum position token-scan can be
  thrown off by a top-level struct-literal `{` (rare); no member completion / member signatureHelp (Phase-3
  SemanticIndex); no builtins/snippets in completion. **NEXT = Phase 3: the SemanticIndex** — per-node positions +
  definition sites + recorders, the foundation for hover / go-to-definition / member completion / references /
  rename (the big one; needs the deferred expression-precise positions + cross-module resolution).
- **2026-08-03 — PHASE 3.0 DONE: the SemanticIndex foundation + hover + same-file go-to-definition.** The full
  Phase-3 campaign was ratified (Karl: "go the whole way"); a 5-agent recon sized it (~1,400–1,900 Ingle LOC over
  A positions / B def-sites / C recorders / D cross-module) and — crucially — found prerequisite **A was ALREADY
  DONE**: commit `51b1701` had threaded each expression's `(eline, ecol)` through `check_expr` for exactly this.
  So 3.0 is: **`selfhost/semindex.ig`** — the position-keyed store as PARALLEL ARRAYS (OFI-061: no array-of-struct
  mutation) with an innermost-covering-span `lookup` returning a `SemHit` BY VALUE (SK_LOCAL..SK_MODULE kinds),
  mirroring include/semindex.h. **Checker recorders**: index fields + `idx_on` flag + `sem_rec` + a `sem_type_name`
  (SemType-band → source string) renderer; `Local` gained `def_line/def_col`, free fns gained `fn_dl/fn_dc` (the
  `fn` keyword position). Recording wired into the `check_expr` EIdent arm (locals → SK_LOCAL with inferred type,
  bare fn/variant refs) + the ECall callee (fn calls → SK_FUNCTION with def-site). `run_checker` refactored to
  share `build_run(decls, path, idx_on) -> Checker`; new `check_index(src, path) -> si.SemIndex` (index-on, returns
  the cloned arrays — OFI-228). **lsp.ig**: `hover` (markdown card of the type/signature at the cursor) +
  `definition` (jump to `def_line/col`, same-file); capabilities advertise both. VERIFIED: hover on a local shows
  its inferred type (`let sum: int`), go-to-def on a call jumps to the fn. Gated: `run-lsp-self.sh` +2 (15 total),
  `make verify` all-9-green, selfhost 1824/0, reproduction fixed point + bootstrap intact, NO reseed. GOTCHA banked:
  adding a struct field slipped past `make` (its emit path is UNCHECKED — cgen_c_dump trusts input) but `make
  selfhost`'s checked `--emit=c` differential caught the missed `Local{}` construction site ("every struct field
  must be set exactly once") — gate struct changes on `make selfhost`, not `make`.
- **2026-08-03 — PHASE 3.1: MEMBER COMPLETION (the daily-driver trio complete).** `receiver.|` now completes off
  the SemanticIndex: `member_completion` (lsp.ig) finds the receiver identifier before the dot, looks up its
  resolved TYPE in the index (`check_index` → `SemHit.type_str`, generics stripped), then lists that struct's
  fields (kind 5) + methods (kind 2), or that enum's variants (kind 20), from the AST. The `member_context` branch
  of `completion` (which Phase 2 stubbed to empty) now routes here. Verified `p.|` → `x: int`, method `mag`. Gated
  (run-lsp-self.sh, `make selfhost` 1824/0). So **hover + go-to-definition + member completion all work.** Limits:
  simple ident/self receiver only (chained/call-result later); the receiver must be a recorded local. **NEXT within
  Phase 3: widen recorders (fields/methods/types/params → richer hover + more go-to-def); semanticTokens (full
  coverage + delta-encode); references/rename (cross-module + a dir-walk native); inlayHint/prover last.**
- **2026-08-02 — PHASE 3 SCOPED (5-agent read-only recon) + Karl ratified the FULL campaign ("go the whole way").**
  The C SemanticIndex (`include/semindex.h` SemEntry {line,col,end_col, kind, type, detail, container, doc, value,
  byte_offset/size, def_file/line/col, ref_file}; flat array; innermost-covering-span lookup; ~10 recorders wired
  into ~30–57 check.c sites; built over the MERGED multi-module program so it's inherently workspace-wide). Sizing:
  ~1,400–1,900 Ingle LOC + invasive parser/checker + a cross-module subsystem + a new directory-walk runtime native.
  KEY enabler found: positions via **option (b) — make `check_expr` take `Box<Expr>`** (~35 checker-only edits, NO
  emit-path ripple) instead of adding position fields to the Expr enum (468 match-arm ripple across codegen/cgen_c).
  Field-name precision from capturing the discarded EGet `.name` token position (a side table, not the enum ripple).
  Def-sites: Tier-A fn/method/interface positions are already in the AST (FnDecl.line/col); Tier-B struct/enum/field/
  variant/global need parser name-token capture; `Local` needs def_line/col. `local_slot(name)` already resolves a
  local use → its exact def index (discarded today) — the ready-made use→def arrow. Cross-module (D) is a genuine
  new subsystem: retrofit the checker to run over `compile_c.load_modules`'s merged decls (thread current_module) +
  a workspace `.ig` walk (new runtime native). **EXECUTION ORDER (gate green + commit each): 3.0** index struct +
  SemType→string renderer + positions (option b) + def-sites + recorders → hover + same-file definition; **3.1**
  semanticTokens (full recorder wiring + sort + delta-encode); **3.2** member completion (receiver-type-at-position;
  members from existing sf_*/sm_*/ev_* tables); **3.3** cross-module (D) → references + rename; **3.4** inlayHint +
  the prover port (greenfield, last). Recon detail: the 5 reports are archived in the session; this is the plan.
- **2026-08-01 — RE-SCOPE CORRECTED: the Phase-1b "wall" was largely a false alarm (scoped via a 5-agent
  read-only recon + hands-on verification against stage-0).** The return-typing frontier had already MOVED far
  past the Phase-1b framing: structs/fields/generics/method-chains all resolve (**234/235** corpus programs
  emit clean), and **`std/json` + `std/string` compile to native binaries today** (the Phase-1b "json won't
  compile" was the stale-binary Makefile bug, since fixed in `4fe6469`). The *real* correction: **`s.substring(…)`
  UFCS-on-a-string is INVALID Ingle** — stage-0 rejects it (`no such string method`); the corpus/stdlib always
  call the `std/string` free fns QUALIFIED (`str.substring(s,…)`, `str.index_of(header, name)` — exactly what
  `std/http_server` does for LSP-shaped header parsing). My reverted skeleton had used the invalid UFCS form,
  which is what "hit OFI-173 in the transport." **So the transport is writable TODAY** with idiomatic qualified
  calls + `std/json`; it is NOT gated on a big return-typing campaign. Of the three "gaps" scoped: **(1)** UFCS-on-string
  = phantom (invalid syntax); **(2)** an inline string method on a `[string]`-returning call/method result
  (`let ns = f(); ns[i].len()`) = a genuine but narrow gap, **FIXED** (`fn_ret_elem_str` on `FnResolve`, `make
  verify` all-9-green — [OFI-226](../OFI.md)); **(3)** value-struct `.clone()` in native = **OFI-082** (a feature
  gap, not return-typing). The big "checker stamps types → C-emit consumes" rearchitecture stays deferred to
  the **SemanticIndex** phase (hover/definition), where it is genuinely required — not a transport prerequisite.
  **Next: resume the port at Phase 1 (transport + diagnostics) on solid ground.**
