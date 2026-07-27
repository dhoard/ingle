// tests/selfhost/cgen_c/for_loop_string_elem.ig — for-loop over a [string], calling a string method on the
// loop var (OFI-173, un-dodged). `for w in words { w.len() }`: the loop var is typed a refcounted borrow
// (array_elem_is_refc_leaf → set_last_refc) so `w.len()` resolves to em_str_len, mirroring a direct
// `words[i].len()`. Previously the loop var was untyped and `w.len()` hit "unresolved callee". em_index
// borrows the element (the array owns it), so the loop var is NOT dropped. Byte-identical to stage-0.
// Returns 2 + 3 + 1 + (split: 3) = 9.
fn main() -> int {
    let words = ["ab", "cde", "f"]
    var total = 0
    for w in words {
        total = total + w.len()
    }
    let csv = "a,b,c"
    for part in csv.split(",") {
        total = total + part.len()
    }
    return total
}
