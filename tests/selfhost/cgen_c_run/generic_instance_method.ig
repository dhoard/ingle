// tests/selfhost/cgen_c_run/generic_instance_method.ig — a method call on a generic-INSTANCE receiver reached
// through a non-ident expression (OFI-224, found dogfooding quog). `h.p.first()` — the receiver `h.p` is a
// Pair<int,int> field, whose struct_sid_any is a generic-INSTANCE sid that sits BEYOND the base `names` table
// (base structs 0..N-1, monomorphised instances N+). The C-emit resolved the method name as
// `{st.names[rsid]}.first`, indexing names with the instance sid → an out-of-bounds CRASH of the compiler
// itself (an Ingle array-bounds fault in cgen_c.ig). The erased model wants the BASE generic method anyway, so
// every such site now maps the sid through st.base_of before indexing names (Pair<int,int> -> "Pair" ->
// fn_index("Pair.first")). RUN-identity vs the VM. Runs to 7.
struct Pair<A, B> {
    a: A
    b: B


    fn first(self) -> A {
        return self.a
    }
}


struct Holder {
    p: Pair<int, int>
}


fn main() -> int {
    let h = Holder { p: Pair<int, int> { a: 7, b: 9 } }
    return h.p.first()       // a generic-instance method call on a non-ident receiver — the base_of path
}
