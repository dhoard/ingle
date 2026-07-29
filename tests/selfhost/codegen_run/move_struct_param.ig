// tests/selfhost/codegen_run/move_struct_param.ig — a `move` value-struct param (OFI-224 VM-parity). A `move`
// param TAKES OWNERSHIP of one BOXED Value, so the self-hosted VM backend must (a) BOX_STRUCT an all-scalar
// value-struct ARG into a single slot at the call site — a non-generic callee's param quals now come from an
// all-fns table on WitInfo, since GenFns only records generics — and (b) declare the callee's move param BOXED
// AND DROPPABLE so its box is freed at scope exit. It was spreading the arg's N leaf slots (ABI mismatch →
// segfault) and never dropping the box. (Returning a moved struct param needs move-linearity — a separate
// larger fix — so this fixture consumes the moved value rather than returning it.) RUN-identity fixture.
// Runs to eat(P{4,5}) + eat(q) = 9 + 30 = 39.
struct P {
    x: int
    y: int
}


fn eat(move p: P) -> int {
    return p.x + p.y          // p read via GET_FIELD (boxed), then its box dropped at return
}


fn main() -> int {
    let a = eat(P { x: 4, y: 5 })   // a value-struct LITERAL arg -> boxed for the move param
    let q = P { x: 12, y: 18 }
    let b = eat(q)                   // a value-struct LOCAL arg -> boxed for the move param
    return a + b                     // 9 + 30 = 39
}
