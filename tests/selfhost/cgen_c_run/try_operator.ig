// tests/selfhost/cgen_c_run/try_operator.ig — the `?` (try) operator in the self-hosted C-emit (OFI-173,
// un-dodged). `o?` on Option<T>/Result<T,E> yields the success payload (Some/Ok = tag 0) or RETURNS the
// whole None/Err value early from the enclosing function (tag != 0). emit_expr's new ETry case lowers it as
// a GCC statement-expression `({ Value t = <op>; if (em_tag(t) != 0) { return t; } em_enum_field(&g_em, t, 0); })`
// so it works in ANY expression position — a `let v = o?` binding AND mid-expression `Ok(a()? + b()?)`.
// Run-identical to the VM (NOT byte-identical: stage-0 hoists the check to real statements + uses em_enum_take;
// this statement-expression form also does not drop abandoned owning temps on the early-return path — a leak,
// sound). Prints: some 42 / ok 7 / err neg.
enum Option<T> { Some(value: T)  None }
enum Result<T, E> { Ok(value: T)  Err(error: E) }


fn plus_one(o: Option<int>) -> Option<int> {
    let v = o?                                  // ? on Option: unwrap Some, or return None early
    return Some(v + 1)
}


fn checked(x: int) -> Result<int, string> {
    if x < 0 {
        return Err("neg")
    }
    return Ok(x)
}


fn sum2(a: int, b: int) -> Result<int, string> {
    return Ok(checked(a)? + checked(b)?)        // ? fires mid-expression, twice
}


fn main() {
    match plus_one(Some(41)) {
        case Some(v) { println("some {v}") }
        case None    { println("none") }
    }
    match sum2(3, 4) {
        case Ok(v)  { println("ok {v}") }
        case Err(e) { println("err {e}") }
    }
    match sum2(0 - 1, 4) {
        case Ok(v)  { println("ok {v}") }
        case Err(e) { println("err {e}") }
    }
}
