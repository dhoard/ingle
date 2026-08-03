// semindex.ig — the SemanticIndex: a position-keyed table of resolved identifier occurrences, built by the
// checker (checker.ig, index-on runs) and consumed by the language server (lsp.ig). It is the foundation the
// intelligent providers ride on — hover, go-to-definition, semantic tokens, member completion, references,
// rename. Mirrors the C reference (include/semindex.h + src/semindex.c): a flat, append-only store with an
// innermost-covering-span lookup. Ingle cannot mutate array-element structs in place (OFI-061), so the store
// is PARALLEL ARRAYS rather than a [SemEntry]; a lookup returns a SemHit struct (by value) so the consumer
// never indexes an array field across the module boundary.

// SemKind — what an identifier occurrence DENOTES (drives the hover prefix + the semantic-token type). Mirrors
// the C SemKind (skipping the never-recorded SK_NONE/SK_BUILTIN); an intrinsic method records as SK_METHOD.
let SK_LOCAL: int = 1
let SK_PARAM: int = 2
let SK_FIELD: int = 3
let SK_METHOD: int = 4
let SK_FUNCTION: int = 5
let SK_TYPE: int = 6
let SK_VARIANT: int = 7
let SK_CONSTANT: int = 8
let SK_MODULE: int = 9


// SemHit is one resolved occurrence, returned BY VALUE from lookup/entry. `found` is false for a miss. Spans
// are 1-based [col, end_col); a definition site is (def_line, def_col) in def_file ("" = same file as the ref).
struct SemHit {
    found: bool
    line: int
    col: int
    end_col: int
    kind: int
    type_str: string       // rendered type, e.g. "int" / "[string]" / "Point"
    detail: string         // a one-line hover signature, e.g. "let x: int" / "fn add(a: int, b: int) -> int"
    container: string      // owning module alias or type name, or ""
    doc: string            // the symbol's doc, or ""
    def_line: int          // definition site line (0 = unknown)
    def_col: int           // definition site column (0 = unknown)
    def_file: string       // definition site file ("" = same file as this occurrence)
    ref_file: string       // the file THIS occurrence is in (for cross-file references / the own-file filter)
}


fn no_hit() -> SemHit {
    return SemHit { found: false, line: 0, col: 0, end_col: 0, kind: 0, type_str: "", detail: "", container: "", doc: "", def_line: 0, def_col: 0, def_file: "", ref_file: "" }
}


// SemIndex is the READ-ONLY view the checker hands to lsp.ig: parallel arrays, one slot per occurrence. The
// checker accumulates occurrences in its own fields during an index-on walk and constructs a SemIndex at the
// end (cloning the arrays so they survive the Checker's drop — OFI-228).
struct SemIndex {
    e_line: [int]
    e_col: [int]
    e_end: [int]
    e_kind: [int]
    e_type: [string]
    e_detail: [string]
    e_container: [string]
    e_doc: [string]
    e_def_line: [int]
    e_def_col: [int]
    e_def_file: [string]
    e_ref_file: [string]


    fn count(self) -> int {
        return self.e_line.len()
    }


    // entry returns occurrence `i` as a SemHit (found=true). The caller must pass 0 <= i < count().
    fn entry(self, i: int) -> SemHit {
        return SemHit { found: true, line: self.e_line[i], col: self.e_col[i], end_col: self.e_end[i], kind: self.e_kind[i], type_str: self.e_type[i], detail: self.e_detail[i], container: self.e_container[i], doc: self.e_doc[i], def_line: self.e_def_line[i], def_col: self.e_def_col[i], def_file: self.e_def_file[i], ref_file: self.e_ref_file[i] }
    }


    // lookup returns the INNERMOST occurrence whose 1-based span covers (line, col) — a leaf identifier beats an
    // enclosing occurrence at the same spot (smallest [col, end_col) wins) — or a miss. Linear scan, matching
    // the C reference (the index is short-lived, rebuilt per request).
    fn lookup(self, line: int, col: int) -> SemHit {
        var best = 0 - 1
        var bestw = 1000000000
        var i = 0
        loop {
            if i >= self.e_line.len() {
                break
            }
            if self.e_line[i] == line && col >= self.e_col[i] && col < self.e_end[i] {
                let w = self.e_end[i] - self.e_col[i]
                if w < bestw {
                    bestw = w
                    best = i
                }
            }
            i = i + 1
        }
        if best < 0 {
            return no_hit()
        }
        return self.entry(best)
    }
}
