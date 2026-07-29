// tests/selfhost/codegen_run/module_qualified_const.ig — an import-alias-qualified top-level CONSTANT
// `L.COL` (OFI-224 VM-parity). A module alias is inert (the checker erases the qualifier), so `L.COL`
// should inline the folded global exactly like a bare `COL`. gen_field_access only recognised a qualified
// zero-field ENUM variant off a non-slot identifier and hard-failed "field access `.COL` on an untypeable
// object" for a qualified constant; it now also inlines a global constant reached through the alias.
// RUN-identity fixture. std/layout defines COL=0, ROW=1, START=0, CENTER=1, STRETCH=3.
import "std/layout" as L


fn main() -> int {
    let a = L.COL          // 0
    let b = L.ROW          // 1
    let c = L.STRETCH      // 3
    println("a={a} b={b} c={c}")
    return a + b + c       // 0 + 1 + 3 = 4
}
