// tests/selfhost/codegen/multislot_field_read.ig — a field read off a call that RETURNS an all-scalar
// (multi-slot) value struct, in the self-hosted VM bytecode backend (OFI-224 VM-parity). `mk(1,2).x` returns
// the Point as N exploded leaf slots (RETURN_STRUCT N); gen_field_access now BOX_STRUCTs those slots into a
// heap struct then GET_FIELD_OWNED extracts the field (dropping the box) — the multi-slot-call-result carve-out
// codegen had deferred. Byte-identical to stage-0 --emit=bytecode.
struct Point {
    x: int
    y: int
}


fn mk(a: int, b: int) -> Point {
    return Point { x: a, y: b }
}


fn main() -> int {
    return mk(3, 4).x + mk(5, 6).y      // 3 + 6 = 9
}
