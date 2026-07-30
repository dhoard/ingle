// tests/selfhost/cgen_c_run/boxed_struct_return_owning_arg.ig — a free fn returning a BOXED (rc/resource)
// struct, CALLED with an owning-temp argument (OFI-224 v1.0 cutover, the std/proc `run_argv([...]) -> Run`
// crash class). An owning-temp arg (here the array literal) makes the C-emit wrap the call in a cleanup block
// `({ Value c2 = <arg>; <rtype> c1 = em_fn_0(c2); drop_value(c2); c1; })`. The result temp's <rtype> was typed
// `em_s{sid}` whenever the callee returned ANY struct sid — but an `rc`/`resource` struct is BOXED, so the
// callee returns a Value, and `em_s0 c1 = <Value>` does not compile (the self-hosted native emit hard-CC-failed
// on std/proc). The result-temp rtype now gates em_s on st.is_value (matching the sibling bounded-call path and
// stage-0), so a boxed-struct return stays a Value. RUN-identity vs the VM. Runs to id=3.
rc struct Handle {
    id: int
}


fn make_handle(tags: [string]) -> Handle {   // owning-temp array arg + a BOXED (rc) struct return
    return Handle { id: tags.len() }
}


fn main() -> int {
    let h = make_handle(["a", "b", "c"])       // the cleanup-block result temp must be Value, not em_s{Handle}
    println("id={h.id}")                        // 3
    return h.id                                 // 3
}
