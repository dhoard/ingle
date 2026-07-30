// tests/selfhost/codegen_run/closure_value_struct_param.ig — a CLOSURE taking a value-struct parameter,
// boxed across the indirect call (OFI-224 VM-parity). A lambda `|q| q.x + q.y` bound to `fn(Point)->int`:
//   * its param q must be TYPED (from the fn-type annotation / HOF param type) so `q.x` resolves — the self
//     backend left an untyped lambda param, hard-failing "field access `.x` on an untypeable object". A new
//     pending_lambda_ptys threads the annotation's struct param names to the lifted lambda (annotate_ptype_params).
//   * the closure ABI is uniform, so a value-struct param arrives BOXED (1 slot, GET_FIELD) — the lambda is
//     compiled with in_lambda set so declare_param boxes it (like a generic method), and gen_closure_call
//     BOX_STRUCTs a value-struct arg before CALL_CLOSURE (was passing a single raw field slot -> wrong value).
// RUN-identity fixture. Runs to apply(add, {3,6})=9 and apply(diff, {10,4})=6 -> 9 + 6 = 15.
struct Point {
    x: int
    y: int
}


fn apply(f: fn(Point) -> int, p: Point) -> int {
    return f(p)
}


fn main() -> int {
    let add: fn(Point) -> int = |q| q.x + q.y
    let diff: fn(Point) -> int = |q| q.x - q.y
    let a = apply(add, Point { x: 3, y: 6 })      // 9
    let b = apply(diff, Point { x: 10, y: 4 })    // 6
    println("a={a} b={b}")
    return a + b                                   // 15
}
