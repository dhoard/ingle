// tests/selfhost/codegen_run/move_param_struct_return.ig — returning a `move` value-struct PARAM (OFI-224
// VM-parity). A `move` param owns its value and is stored BOXED (one slot), but a function returning an
// all-scalar struct returns it MULTI-SLOT (RETURN_STRUCT spans N leaf slots). `return p` was emitting the
// single boxed slot where N slots are read, so the caller's `q.x` read the boxed object (`<obj>`) instead
// of the field. The return path now, for a boxed value-struct local/param, moves it out (gen_consume nils
// the owned slot) then UNBOX_STRUCTs it into its N leaf slots before RETURN_STRUCT. RUN-identity fixture.
// Runs to into_x(Point{9,4}).x + shift(Point{9,4}).y = 9 + 5 = 14.
struct Point {
    x: int
    y: int
}


fn into_x(move p: Point) -> Point {
    return p                       // the move param is returned as-is
}


fn shift(move p: Point) -> Point {
    p.y = p.y + 1                  // mutate the owned copy, then return it
    return p
}


fn main() -> int {
    let a = Point { x: 9, y: 0 }
    let q = into_x(a)              // a moved into the call
    let b = Point { x: 0, y: 4 }
    let r = shift(b)
    println("qx={q.x} ry={r.y}")   // 9 5
    return q.x + r.y               // 9 + 5 = 14
}
