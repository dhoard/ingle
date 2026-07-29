// tests/selfhost/codegen_run/free_fn_intrinsics.ig — the FREE-FUNCTION intrinsic forms `len(x)` and
// `assert(cond)` (and `clock()`, exercised separately since its value is nondeterministic). These are not real
// functions: the self-hosted VM backend had no special case, so each fell through to the free-call path,
// resolve_free_fn returned -1, and a bogus `CALL 255 …` truncated the function → VM segfault. Now `len(arr)`
// lowers to ARRAY_LEN (`len(str)` to STR_LEN), and `assert(cond)` to CONTRACT_CHECK (a fault on failure) + a
// CONST 0 filler — mirroring stage-0. RUN-identity fixture. Runs to len([..])=4 + n=5 → 9. (`len` is array-only
// in Ingle — the checker rejects `len(string)` — so only the ARRAY_LEN path is reachable in a valid program.)
fn main() -> int {
    let xs = [10, 20, 30, 40]
    let n = 5
    assert(n > 0)
    assert(len(xs) == 4, "xs must have four elements")
    return len(xs) + n     // 4 + 5 = 9
}
