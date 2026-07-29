// tests/selfhost/codegen_run/match_payload_struct.ig — two connected VM-backend fixes (OFI-224):
//  (1) a `case Some(x)` / `case Ok(x)` arm over a scrutinee typed `Option<Struct>` / `Result<Struct, …>` (a
//      PARAM or annotated local) must type the payload binding `x` by its concrete struct, so `x.field` /
//      `x.method()` resolve. The prelude Some/Ok payload fields are deliberately absent from the enum field
//      table, so the resolver reads the subject's recorded type-args (erecv) directly — and enum-typed PARAMS
//      are now registered in erecv, not only annotated locals. It hard-failed "field access on untypeable object".
//  (2) an all-scalar value-struct passed as an enum variant PAYLOAD (`Some(Pt{..})`) must be BOXED (NEW_STRUCT)
//      before NEW_ENUM — one Value per payload field. It was pushing raw fields → NEW_ENUM read the wrong stack
//      shape → segfault. gen_boxed_payload boxes a value-struct payload (literal or multi-slot call result).
// RUN-identity fixture. Runs to sum(node).head + area(res) = 11 + 12 = 23.
struct Pt {
    x: int
    y: int
}


fn first_x(node: Option<Pt>) -> int {
    match node {
        case Some(p) { return p.x + p.y }   // p typed Pt from the Option<Pt> param -> p.x/p.y resolve
        case None    { return 0 }
    }
}


fn area(res: Result<Pt, string>) -> int {
    match res {
        case Ok(p)  { return p.x * p.y }    // p typed Pt from the Result<Pt, …> param
        case Err(m) { return 0 }
    }
}


fn main() -> int {
    let a = first_x(Some(Pt { x: 5, y: 6 }))   // value-struct payload boxed before NEW_ENUM -> 11
    let b = area(Ok(Pt { x: 3, y: 4 }))        // -> 12
    return a + b                                // 11 + 12 = 23
}
