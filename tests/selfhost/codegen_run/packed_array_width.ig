// tests/selfhost/codegen_run/packed_array_width.ig — arithmetic + interpolation over a PACKED-scalar array
// element carries the element WIDTH (OFI-224 VM-parity). `big[0] + big[0]` on a `[u64]` must add at u64
// (unsigned, modular — no signed-overflow trap) and `{big[0]}` must render unsigned; the backend tracked
// only slot_elem (the element TYPE code) per array local, not the packed scalar width, so `big[0]` inferred
// int-0 → the add trapped on 9e18+9e18 = 1.8e19 (fits u64, overflows i64) and the hole rendered signed.
// New slot_elem_kind (ty_scalar_kind of the `[T]` annotation, threaded like slot_elem_targs incl. truncate_to)
// feeds scalar_kind_of/render_kind_of's EIndex case. RUN-identity fixture. Runs to the two println lines.
fn main() -> int {
    var big: [u64] = [9000000000000000000]
    big[0] = big[0] + big[0]        // 1.8e19 — u64 add, no trap
    let half = big[0] / 3            // unsigned divide
    println("doubled={big[0]} half={half}")

    let reals: [f32] = [1.5, 2.5]
    let r = reals[0] + reals[1]      // 4.0 (f32)
    println("r={to_int(r)}")         // 4
    return 0
}
