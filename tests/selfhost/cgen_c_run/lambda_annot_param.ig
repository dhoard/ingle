// tests/selfhost/cgen_c_run/lambda_annot_param.ig — a lambda whose param STRUCT type comes from a fn-TYPE
// ANNOTATION on its binding (`let g: fn(Point) -> int = |q| q.x + q.y`), then dispatched indirectly through a
// higher-order fn (OFI-206, un-dodged). Two gaps this closes in the self-hosted C-emit:
//   (1) record_annotated_lambda types the lifted lambda's param `q` as Point from the annotation (the OTHER
//       source of lambda param typing besides a determining HOF arg), so `q.x` reads the boxed param via
//       em_enum_field rather than hitting "unsupported field access";
//   (2) the value-struct arg to the closure call (`f(p)` inside apply, p: Point) is BOXED across the erased
//       indirect call — emit_consume_arg (stage-0's emit_value_arg convention) — not passed as a bare em_s.
// Run-identical to the VM (the erased lambda param is a boxed Value, not a monomorphised em_s). Returns
// g(3,6) + g(10,20) = 9 + 30 = 39.
struct Point {
    x: int
    y: int
}


fn apply(f: fn(Point) -> int, p: Point) -> int {
    return f(p)                              // p (a value struct) is BOXED across the erased closure call
}


fn main() -> int {
    let g: fn(Point) -> int = |q| q.x + q.y  // q typed Point from the annotation → `q.x` via em_enum_field
    let a = apply(g, Point { x: 3, y: 6 })   // 9
    let b = apply(g, Point { x: 10, y: 20 }) // 30
    println("a={a} b={b}")
    return a + b                             // 39
}
