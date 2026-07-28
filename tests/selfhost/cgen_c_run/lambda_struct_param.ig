// tests/selfhost/cgen_c_run/lambda_struct_param.ig — a lambda whose param is a (flat) STRUCT, typed from the
// call context, in the self-hosted C-emit (OFI-206, un-dodged). `spanned<T>(f: fn(T)->int, x: T)` called
// `spanned(|p| p.x + p.y, Pt{…})` — the lambda param p is T = Pt, but it is stored BOXED in the lifted lambda's
// Value slot (erased). Previously `p.x` hit "unsupported field access": the lambda-lift recorded only scalar/
// string param types. Now record_hof_lambdas also records the param's struct sid (a lam_pstruct facet threaded
// through emit_fn_body via a stride-3 lam_recs), and a sc_boxed_vstruct marker makes `p.field` read via
// em_enum_field (the boxed slot holds a Value, not an em_s) rather than a `.fN` value read. Run-identical to the
// VM (the erased boxed lambda param — a cgen_c_run divergence). Returns 3 + 30 = 33.
struct Pt {
    x: int
    y: int
}


fn spanned<T>(f: fn(T) -> int, x: T) -> int {
    return f(x)
}


fn main() -> int {
    let a = spanned(|p| p.x + p.y, Pt { x: 1, y: 2 })            // 3
    let b = spanned(|q| q.x * q.y - 2, Pt { x: 4, y: 8 })        // 32 - 2 = 30
    return a + b                                                 // 3 + 30 = 33
}
