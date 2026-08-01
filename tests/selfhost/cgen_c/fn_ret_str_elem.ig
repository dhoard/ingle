// C-emit: an inline string method on the element of a `[string]`-returning CALL result — the binding's
// element AEK is recovered from the fn's declared return type (fn_ret_elem_str on FnResolve), so `ns[i].len()`
// resolves as a string method with no bind-to-local. Covers a free fn AND a struct method return. (OFI-173.)
struct Doc {
    tag: int


    fn lines(self) -> [string] {
        return ["aa", "bbb"]
    }
}


fn names() -> [string] {
    return ["alice", "bob"]
}


fn main() -> int {
    let ns = names()                 // free fn -> [string]
    let d = Doc { tag: 0 }
    let ls = d.lines()               // struct method -> [string]
    return ns[0].len() + ns[1].len() + ls[0].len() + ls[1].len()   // 5 + 3 + 2 + 3 = 13
}
