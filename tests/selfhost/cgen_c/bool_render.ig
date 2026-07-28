// tests/selfhost/cgen_c/bool_render.ig — bool-valued interpolation holes in the self-hosted C-emit (OFI-202,
// un-dodged). A `{expr}` hole whose value is a bool must render "true"/"false", not the raw 1/0. render_kind_of_expr
// had no EBinary/EUnary case, so a comparison/logical hole (`{a < b}`, `{!c}`) fell through to render-kind 0 (int);
// and a bool BINDING (`let ok = a.contains(k)`) carried no render-kind. Now render_kind_of_expr returns 10 for a
// comparison/logical operator (binop_id 6..13) or `!`, and the SLet stamps render-kind 10 on a bool-valued binding
// (via render_kind_of_expr of the RHS — a comparison or a bool-returning call). Byte-identical to stage-0.
// Prints "true false true false true", then returns 1 + 0 + 1 = 2 (bools coerce: true=1 in arithmetic via if).
struct Gate {
    open: bool

    fn is_open(self) -> bool {
        return self.open
    }
}


fn main() -> int {
    let a = 3 < 5                 // a comparison BINDING → renders true
    let b = 3 == 5                // → false
    let g = Gate { open: true }
    let c = g.is_open()           // a bool-returning method BINDING → true
    let d = !c                    // logical-not BINDING → false
    println("{a} {b} {c} {d} {7 > 2}")   // holes: bindings + a direct comparison hole
    var n = 0
    if a { n = n + 1 }            // true  → +1
    if c { n = n + 1 }            // true  → +1
    return n                      // 2
}
