// tests/selfhost/cgen_c/len_free_fn.ig — the FREE-FUNCTION form `len(a)` in the self-hosted C-emit (OFI-173,
// un-dodged). `len(a)` is the array-length builtin's free form (the checker restricts it to an array arg);
// cgen_c lowers it exactly like the `a.len()` method form — em_array_len for a binding, and a fresh array TEMP
// (a literal / call result) measured then dropped so it can't leak. Previously `len(a)` hit "unresolved callee"
// (only the method form was handled). Byte-identical to stage-0. Returns 3 + 4 + (10+30) = 47.
fn main() -> int {
    let a = [10, 20, 30]
    let n = len(a)                       // binding receiver → em_array_len(a)
    let m = len([1, 2, 3, 4])            // TEMP literal receiver → measured then dropped
    return n + m + (a[0] + a[2])         // 3 + 4 + 40 = 47
}
