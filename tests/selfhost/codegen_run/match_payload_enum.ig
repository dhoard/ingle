// tests/selfhost/codegen_run/match_payload_enum.ig — a `case Ok(v)` / `case Some(v)` arm whose payload is an
// ENUM, over a scrutinee typed Result<Enum, …> / Option<Enum> (a param or annotated local) — OFI-224 VM-parity.
// The payload binding must be a REFCOUNTED borrow (INCREF when consumed / passed on, but the scrutinee still
// owns it), else passing v onward hit a use-after-free. subject_prelude_payload_code now returns an enum code
// (-4) for an enum-typed payload and the match binding marks it refcounted. RUN-identity fixture. Runs to
// depth(Ok(Node(Leaf))) + depth(Ok(Leaf)) = 2 + 1 = 3.
enum Tree {
    Leaf
    Node(child: Tree)
}


fn depth(r: Result<Tree, string>) -> int {
    match r {
        case Ok(t)  { return height(t) }   // t is an enum payload -> refcounted borrow
        case Err(e) { return 0 }
    }
}


fn height(t: Tree) -> int {
    match t {
        case Leaf       { return 1 }
        case Node(c)    { return 1 + height(c) }
    }
}


fn main() -> int {
    let a: Result<Tree, string> = Ok(Node(Leaf))
    let b: Result<Tree, string> = Ok(Leaf)
    return depth(a) + depth(b)     // 2 + 1 = 3
}
