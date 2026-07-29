// tests/selfhost/codegen_run/array_pop_struct_elem.ig — `let e = arr.remove_last()` / `arr.remove_at(i)` on a
// STRUCT array returns the array's ELEMENT, so the binding must inherit the element's struct type for `e.field`
// to resolve (OFI-224 VM-parity). The self-hosted VM backend left the binding untyped (expr_ret_kind had no
// remove_last/remove_at case) and `e.x` hard-failed "field access on an untypeable object". expr_ret_kind now
// returns the array receiver's element struct sid, and the multi-slot let unboxes the BOXED popped element into
// leaf slots (ARRAY_POP returns one boxed Value; stage-0 emits `ARRAY_POP; UNBOX_STRUCT`). RUN-identity fixture
// (not byte-identical: nested/array struct representation diverges). Runs to last.x + last.y + at.x = 5+6+3 = 14.
struct Pt {
    x: int
    y: int
}


fn main() -> int {
    var pts = [Pt { x: 1, y: 2 }, Pt { x: 3, y: 4 }, Pt { x: 5, y: 6 }]
    let last = pts.remove_last()      // {5, 6}
    let at = pts.remove_at(1)         // {3, 4}
    return last.x + last.y + at.x     // 5 + 6 + 3 = 14
}
