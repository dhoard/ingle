// tests/selfhost/cgen_c_run/fn_value_call_result.ig — calling a function VALUE returned by a call (or read from
// an array), in the self-hosted C-emit (OFI-206, un-dodged). The closure-call dispatch already handled a fn-value
// BINDING/PARAM (`f(x)`, `g(7)`), but a callee that is itself a CALL — `pick(true)(9)`, where pick returns a
// `fn(int)->int` — or an INDEX `fns[i](x)` fell through to "unresolved callee". emit_call now routes an ECall /
// EIndex callee through emit_closure_call (rt_call_closure on the evaluated callee). Run-identical to the VM.
// Returns 18 + 30 = 48.
fn double(x: int) -> int {
    return x * 2
}


fn inc(x: int) -> int {
    return x + 1
}


fn pick(up: bool) -> fn(int) -> int {
    if up {
        return double
    }
    return inc
}


fn main() -> int {
    let a = pick(true)(9)          // a fn-value RETURNED then called → double(9) = 18
    let fns: [fn(int) -> int] = [double, inc]
    let b = fns[0](15)            // a fn-value read from an array then called → double(15) = 30
    return a + b                  // 18 + 30 = 48
}
