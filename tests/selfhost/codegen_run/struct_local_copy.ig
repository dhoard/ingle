// tests/selfhost/codegen_run/struct_local_copy.ig — a whole-struct COPY binding `let q = p` where `p` is a
// multi-slot value-struct local/param. The self-hosted VM backend fell through to a scalar binding (q untyped),
// so `q.field` hard-failed "field access on an untypeable object". A multi-slot local read is now spread to its
// N leaf slots, BOX_STRUCT + UNBOX_STRUCT makes a fresh INDEPENDENT copy (the source stays usable — value
// semantics), and q binds multi-slot — mirrors stage-0's `GET_LOCAL..; BOX_STRUCT; UNBOX_STRUCT`. RUN-identity
// fixture. Runs to q.x + q.y + p.x = 3 + 4 + 3 = 10 (p unchanged by the copy).
struct Pt {
    x: int
    y: int
}


fn copyback(p: Pt) -> int {
    let q = p                  // a fresh multi-slot copy; p stays usable
    return q.x + q.y + p.x     // 3 + 4 + 3 = 10
}


fn main() -> int {
    return copyback(Pt { x: 3, y: 4 })
}
