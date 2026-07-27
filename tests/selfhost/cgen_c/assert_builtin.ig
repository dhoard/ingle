// tests/selfhost/cgen_c/assert_builtin.ig — the `assert(cond [, "msg"])` builtin in the self-hosted C-emit
// (OFI-173, un-dodged). Lowers to em_assert(<cond>, <msg>): the message is a RAW C string literal (via
// c_escape), or 0 for the auto-message form — matching stage-0's contract-check machinery (release-elided).
// Byte-identical to stage-0. Returns 5.
fn checked_div(a: int, b: int) -> int {
    assert(b != 0, "divisor must be nonzero")
    return a / b
}


fn main() -> int {
    let x = checked_div(10, 2)
    assert(x == 5)                          // auto-message form → em_assert(cond, 0)
    assert(x > 0, "x should be positive")
    return x
}
