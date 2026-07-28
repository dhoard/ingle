// tests/selfhost/cgen_c_run/generic_return_array.ig — field access / indexing on an element of a generic free
// fn's `[T]` return, in the self-hosted C-emit (OFI-202, un-dodged). `pair<T>(a, b) -> [T]`:
//   - with P value-struct args → [P], and `ps[i].x` needs ps's element STRUCT (value_elem_struct resolves it
//     from the determining arg fn_ret_det_arg — a bare T, so the element = the arg's struct);
//   - with array args → [[int]], and `xss[i].len()` needs the element to be an ARRAY (value_elem_is_array
//     resolves the same way).
// Previously both hit "unsupported field access" / "unresolved callee _[i].len". Run-identical to the VM
// (erased element — the cgen_c_run divergence). Returns (10+20+1+2) + (3+2) = 38.
struct P { x: int  s: string }


fn pair<T>(a: T, b: T) -> [T] {
    return [a, b]
}


fn main() -> int {
    let ps = pair(P { x: 10, s: "a" }, P { x: 20, s: "bb" })
    let a = ps[0].x + ps[1].x + ps[0].s.len() + ps[1].s.len()   // 10 + 20 + 1 + 2 = 33
    let xss = pair([1, 2, 3], [9, 8])
    let b = xss[0].len() + xss[1].len()                         // 3 + 2 = 5
    return a + b                                                // 38
}
