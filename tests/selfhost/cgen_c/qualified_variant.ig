// tests/selfhost/cgen_c/qualified_variant.ig — QUALIFIED enum-variant references `Enum.Variant` in the
// self-hosted C-emit (OFI-013/OFI-173, un-dodged). A variant may be named through its enum: `Color.Red`,
// `Option.None`, `Color.Blue(5)`, `Option.Some(7)`. The checker desugars `Enum.Variant` to the bare variant
// (variant names are globally unique), so cgen_c lowers it identically: is_qualified_variant detects the
// EGet whose receiver is an enum TYPE name (not a binding/struct) and whose field is a variant, then routes
// it through emit_enum_ctor (construction) / is_enum_expr (a binding owns+drops it) / retain_dance (a consume
// retains it) — exactly like a bare `Red`/`None`. Zero-field forms are the EGet path; payload forms
// `Enum.Variant(x)` are the ECall path. Byte-identical to stage-0. Returns 7 + 100 + 5 + 1 = 113.
enum Color { Red  Green  Blue(shade: int) }

fn main() -> int {
    let a = Option.Some(7)                       // qualified, data-carrying (ECall)
    let b: Option<int> = Option.None             // qualified, zero-field (EGet, needs annotation)
    let c = Color.Blue(5)                        // qualified user payload variant (ECall)
    let d = Color.Red                            // qualified user zero-field variant (EGet)
    var s = 0
    match a { case Some(n) { s = s + n } case None { } }                  // +7
    match b { case Some(n) { s = s + n } case None { s = s + 100 } }      // +100
    match c { case Red { } case Green { } case Blue(x) { s = s + x } }    // +5
    match d { case Red { s = s + 1 } case Green { } case Blue(x) { } }    // +1
    return s                                                              // 113
}
