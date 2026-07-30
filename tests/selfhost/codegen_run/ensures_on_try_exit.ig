// tests/selfhost/codegen_run/ensures_on_try_exit.ig — a function's `ensures` postcondition is checked on the
// `?` (try) PROPAGATION exit too, not only on an explicit `return` (OFI-046 / OFI-224 VM-parity). Two bugs:
// (1) the self backend's ETry Err/None path emitted ROUTE_HOP; drops; RETURN with NO ensures check — it now
// parks the propagated value into the fixed `result` slot (SET_LOCAL, surviving abandoned temporaries below a
// mid-expression `?` like `Ok(a()? + b()?)`) and runs emit_ensures, mirroring stage-0. (2) emit_ensures
// declared `result` as a plain (non-refcounted) binding, so passing a REFCOUNTED result (a Result/Option/enum
// or string) to the predicate did NOT INCREF — the predicate then over-released the shared value and the VM
// trapped. result is now droppable/string per the return type (ret_droppable/ret_is_str). RUN-identity fixture.
enum Result<T, E> {
    Ok(value: T)
    Err(error: E)
}


// Holds on success (value non-negative) AND on the propagated error (message is exactly "neg").
fn ok_pos_or_neg_msg(r: Result<int, string>) -> bool {
    match r {
        case Ok(v)  { return v >= 0 }
        case Err(e) { return e == "neg" }
    }
    return false
}


fn checked(n: int) -> Result<int, string> {
    if n < 0 { return Err("neg") }
    return Ok(n)
}


fn f(a: int, b: int) -> Result<int, string>
    ensures ok_pos_or_neg_msg(result)
{
    return Ok(checked(a)? + checked(b)?)   // checked(b)? can fire mid-expression (abandoned temps below)
}


fn main() -> int {
    match f(3, 4) {                        // success exit: ensures holds (7 >= 0)
        case Ok(v)  { println("ok {v}") }
        case Err(e) { println("err {e}") }
    }
    match f(5, -2) {                       // ? propagation exit: ensures holds ("neg" == "neg")
        case Ok(v)  { println("ok {v}") }
        case Err(e) { println("err {e}") }
    }
    return 0
}
