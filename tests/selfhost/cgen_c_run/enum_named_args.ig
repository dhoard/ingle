// tests/selfhost/cgen_c_run/enum_named_args.ig — named-argument enum-variant construction, reordered to
// declared field order, in the self-hosted C-emit (OFI-222/OFI-140, un-dodged). A variant may be built with
// NAMED payload fields (`Rect(w: 4, h: 3)`) in ANY order (`Rect(h: 3, w: 4)`); the construction must emit its
// payloads in the variant's DECLARED order so codegen is identical to a positional build. Stage-0's CHECKER
// reorders; the self-hosted C-emit path runs no checker, so the reorder happens at emit time. The parser used
// to DISCARD arg names (OFI-222) — they are now carried on the ECall AST (`arg_names`), threaded to
// emit_enum_ctor, which emits via a name→declared-position permutation (a permutation of INDICES, since Ingle
// forbids moving Exprs out of the arg array). Positional construction is unchanged; a qualified `Enum.Variant`
// and the prelude `Some`/`Ok` (single payload) also work.
// Run-identical to the VM. The Rect case is asymmetric (w != h) so the REORDER is actually proven.
enum Shape {
    Circle(radius: int)
    Rect(w: int, h: int)
}


fn area(s: Shape) -> int {
    match s {
        case Circle(r) { return r * r }
        case Rect(w, h) { return w * h }      // distinct fields prove the reorder
    }
}


fn main() -> int {
    let a = Rect(w: 4, h: 3)                   // named, declared order   → w=4 h=3, area 12
    let b = Rect(h: 3, w: 4)                   // named, REVERSED         → must still be w=4 h=3, area 12
    let c = Rect(7, 9)                          // positional, unchanged   → w=7 h=9, area 63
    let d = Shape.Circle(radius: 5)             // qualified + named       → area 25
    let e: Option<int> = Option.Some(value: 8)  // qualified prelude, named
    var n = 0
    match e {
        case Some(v) { n = v }
        case None    { n = 0 }
    }
    println("a={area(a)} b={area(b)} c={area(c)} d={area(d)} some={n}")   // 12 12 63 25 8
    return area(a) + area(b) + area(c) + area(d) + n   // 12 + 12 + 63 + 25 + 8 = 120
}
