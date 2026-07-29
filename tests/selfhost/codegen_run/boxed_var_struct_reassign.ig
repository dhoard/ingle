// tests/selfhost/codegen_run/boxed_var_struct_reassign.ig — reassigning a struct-literal RHS into a BOXED
// struct var, `p = Counter{..}` (OFI-224 VM-parity). An all-scalar struct literal pushes N loose leaf slots, but
// SET_LOCAL stores ONE Value into the boxed slot — so the RHS must be BOX_STRUCT'd first. The backend was
// dropping the box (CONST;DROP;SET_LOCAL), landing a raw int in the boxed slot → GET_FIELD segfault. The SAssign
// EIdent path now boxes a multi-slot RHS when the target slot is a boxed struct, like the boxed var-decl path.
// (A struct is boxed as a `var` — mutable — even when all-scalar.) RUN-identity fixture. Runs to p.n = 200.
struct Counter {
    n: int
}


fn main() -> int {
    var p = Counter { n: 1 }        // a mutable struct var is boxed
    p = Counter { n: 200 }          // reassign with a struct-literal RHS -> must NEW_STRUCT/BOX_STRUCT
    return p.n                       // 200
}
