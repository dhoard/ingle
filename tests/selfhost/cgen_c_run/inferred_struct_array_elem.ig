// tests/selfhost/cgen_c_run/inferred_struct_array_elem.ig — element typing of an INFERRED array literal whose
// element is a value-struct with a boxed (refcounted) field, in the self-hosted C-emit (OFI-202, un-dodged).
// `var ts = [Tok { tag, text }]` (no `[Tok]` annotation) mis-inferred the element as an int SCALAR:
// value_elem_kind's EArray case defaulted a struct-literal element to i64 (0). For an all-scalar struct the
// value-struct read path masks it, but a struct with a boxed field is NOT is_value, so `ts[0]` fell through to
// the scalar path and `.tag` hit "unsupported field access". value_elem_kind now returns -1 (not a scalar) for
// a struct/enum element, matching the `[Tok]`-annotated path, so `ts[i].tag` / `let c = ts[i]; c.text.len()`
// resolve. Run-identical to the VM (erased element — the cgen_c_run divergence). Returns 3 + 9 + 2 = 14.
struct Tok { tag: int  text: string }


fn main() -> int {
    var ts = [Tok { tag: 1, text: "ab" }]           // inferred [Tok] — no annotation
    ts.append(Tok { tag: 2, text: "worldly" })
    let copy = ts[0]                                 // a value copy sharing the boxed field
    let from_copy = copy.tag + copy.text.len()       // 1 + 2 = 3
    let from_arr  = ts[1].tag + ts[1].text.len()     // 2 + 7 = 9
    return from_copy + from_arr + ts.len()           // 3 + 9 + 2 = 14
}
