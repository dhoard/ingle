// tests/selfhost/codegen_run/field_assign_struct_rhs.ig — a whole value-struct field assignment with a struct
// LITERAL right-hand side, `parent.field = Inner{..}`, where parent is a BOXED struct (OFI-224 VM-parity). An
// all-scalar struct literal pushes N loose leaf slots, but SET_FIELD stores ONE Value — so the RHS must be
// BOX_STRUCT'd first (store_value_multislot_sid now recognises an EStructLit; the boxed-field-store path routes
// the value through push_store_value). It was pushing raw fields → SET_FIELD stored 1 slot → stack imbalance /
// segfault. RUN-identity fixture. Runs to n.span.a + n.span.b = 99 + 8 = 107.
struct Span {
    a: int
    b: int
}


struct Node {
    span: Span
    tag: int
}


fn main() -> int {
    var n = Node { span: Span { a: 1, b: 2 }, tag: 5 }   // Node is boxed (nested-struct field)
    n.span = Span { a: 99, b: 8 }                         // whole-struct field assign, struct-literal RHS
    return n.span.a + n.span.b                             // 99 + 8 = 107
}
