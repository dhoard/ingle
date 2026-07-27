// tests/selfhost/cgen_c/nested_destructure_prelude.ig — nested struct destructure under a PRELUDE variant in
// the self-hosted C-emit (OFI-173, un-dodged). `case Some(Point(x, y))` — the outer variant is a prelude Some
// whose payload the enum table types as the erased T, so payload_ty finds no user row. The nested-destructure
// branch previously indexed pf_ty[-1] and CRASHED the compiler ("array index out of bounds"). Now payload_ty
// guards the -1, and the branch recovers the concrete payload struct (Point) from the scrutinee's Option<Point>
// — the same concrete-payload path the simple `case Some(r)` branch uses — so the inner value-struct is unboxed
// and its fields (x, y) bound. Byte-identical to stage-0. Returns 507 + 34 + (-1) = 540.
struct Point { x: int  y: int }


fn opt_sum(o: Option<Point>) -> int {
    match o {
        case Some(Point(x, y)) { return x * 100 + y }   // nested destructure under prelude Some
        case None { return 0 - 1 }
    }
}


fn opt_diff(o: Option<Point>) -> int {
    match o {
        case Some(Point(x, y)) { return x - y }         // a second nested-destructure site, ignored none
        case None { return 0 }
    }
}


fn main() -> int {
    let a = opt_sum(Some(Point { x: 5, y: 7 }))         // 507
    let b = opt_diff(Some(Point { x: 40, y: 6 }))       // 34
    let c = opt_sum(None)                               // -1
    return a + b + c                                    // 540
}
