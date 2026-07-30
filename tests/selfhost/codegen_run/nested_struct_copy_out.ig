// tests/selfhost/codegen_run/nested_struct_copy_out.ig — copying a whole NESTED value struct out of a
// parent, as an INDEPENDENT value (OFI-031 / OFI-224 VM-parity). The self backend keeps a non-flat value
// struct BOXED, so `let copy = c.b` (a boxed struct FIELD read) reads a SHARED reference into the source's
// buffer, not a fresh value — the binding fell to the scalar else (struct_id lost) and `copy.a.v` was
// untypeable; and even when typed, a naive alias would leak a later source mutation into the copy. Now a
// boxed value-struct copy-out (a field read always; a bare local when the binding is MUTABLE) binds an
// INDEPENDENT deep copy via OP_INCREF (own_into_slot recursively clones the value-struct buffer). Direct
// chains + nested write-back already worked. RUN-identity fixture proving independence on both shapes.
struct A {
    v: int
}


struct B {
    a: A
    w: int
}


struct C {
    b: B
    z: int
}


struct Line {                    // a FULLY-FLAT nested struct is a multi-slot copy type (var-copy is legal)
    a: A
    b: A
}


fn main() -> int {
    var c = C { b: B { a: A { v: 10 }, w: 2 }, z: 3 }
    c.b.a.v = 20                 // 3-level write-back through nested fields (already worked)

    let copy = c.b               // copy a whole boxed nested struct FIELD out — independent of c
    c.b.a.v = 99                 // mutate c AFTER the copy — copy must be unaffected (stays 20)
    println("c.b.a.v={c.b.a.v} copy.a.v={copy.a.v} copy.w={copy.w}")   // 99 / 20 / 2

    let ln = Line { a: A { v: 1 }, b: A { v: 4 } }
    var dup = ln                 // copy a boxed struct LOCAL out (mutable) — independent of ln
    dup.a.v = 100                // mutate the copy only — ln must be unaffected (stays 1)
    println("ln.a.v={ln.a.v} dup.a.v={dup.a.v} ln.b.v={ln.b.v}")       // 1 / 100 / 4
    return copy.a.v + dup.a.v + c.b.a.v   // 20 + 100 + 99 = 219
}
