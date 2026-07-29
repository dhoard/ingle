// tests/selfhost/codegen_run/struct_literal_and_generic_field.ig — a field/method access DIRECTLY on a struct
// LITERAL, `(Pt{..}).x` (OFI-224). expr_type_kind and value_is_multislot gained an EStructLit case, so
// gen_field_access's multi-slot branch (BOX_STRUCT; GET_FIELD_OWNED) fires on a literal receiver — it hard-failed
// "field access on an untypeable object". (The sibling fix — typing `let hi = max(a,b)` from a bounded-generic
// concrete-struct return via generic_call_ret_sid — is covered end-to-end by the bounded.ig corpus program.)
// RUN-identity fixture. Runs to (Pt{5,9}).x + (Pt{5,9}).y = 5 + 9 = 14.
struct Pt {
    x: int
    y: int
}


fn main() -> int {
    let a = (Pt { x: 5, y: 9 }).x     // field access on a struct literal
    let b = (Pt { x: 5, y: 9 }).y
    return a + b                       // 5 + 9 = 14
}
