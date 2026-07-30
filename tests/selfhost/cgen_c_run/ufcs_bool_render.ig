// tests/selfhost/cgen_c_run/ufcs_bool_render.ig — a UFCS method-style call on a NON-struct receiver whose
// bool result is rendered in a string-interpolation hole (OFI-224 v1.0 cutover). `a.is_ready()` where a is an
// Option (an enum, not a struct) is a UFCS free call the checker leaves un-rewritten. emit_call resolves it
// correctly (fn_index by bare name -> em_fn_N), but render_kind_of_expr's EGet sub-case only handled struct
// methods and module-qualified calls — it fell through to render-kind 0 for the UFCS-on-non-struct case, so the
// bool printed via %lld as "1"/"0" instead of "true"/"false" (native diverged from the VM/stage-0). A UFCS
// fallback (fn_index(mname) -> fn_ret_render) now mirrors emit_call's resolution order. RUN-identity vs the VM.
// Runs to "true false".
fn is_ready(o: Option<int>) -> bool {
    match o {
        case Some(v) {
            return true
        }
        case None {
            return false
        }
    }
}


fn main() -> int {
    let a: Option<int> = Some(5)
    let b: Option<int> = None
    println("{a.is_ready()} {b.is_ready()}")   // UFCS bool result in a hole -> "true false", not "1 0"
    return 0
}
