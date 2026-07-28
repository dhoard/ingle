// tests/selfhost/cgen_c_run/nested_generic_field.ig — chained field access through NESTED generic instances
// and a generic-instance enum payload, in the self-hosted C-emit (OFI-006/OFI-202, un-dodged). A field whose
// declared type is a type-PARAM (`value: T` in Box<T>) has no static f_struct, so a second `.field` on it
// could not resolve. concrete_ty_of now substitutes the receiver's concrete type ARG for the type-param
// (recorded on the binding via sc_ctype / the enum payload via option_payload_concrete_sid): `b.value` on a
// Box<Box<int>> resolves to Box<int>, so `b.value.value` chains; and `case Some(b)` on an Option<Box<int>>
// types b as Box so `b.value` resolves. Previously both hit "unsupported field access".
// Run-identical to the VM (erased generic instances — the established cgen_c_run divergence). Returns 7+11+9 = 27.
struct Box<T> { value: T }


struct Pair<T> { first: T  second: T }


fn main() -> int {
    let b = Box<Box<int>> { value: Box<int> { value: 7 } }
    let a = b.value.value                                   // 7  — chained through Box<Box<int>>
    let p = Pair<int> { first: 11, second: 99 }
    let c = p.first                                         // 11 — a type-param field on a generic instance
    let o: Option<Box<int>> = Some(Box<int> { value: 9 })
    var d = 0
    match o {
        case Some(bx) { d = bx.value }                      // 9  — generic-instance enum payload field
        case None     { d = 0 - 1 }
    }
    return a + c + d                                        // 7 + 11 + 9 = 27
}
