// tests/selfhost/cgen_c_run/value_struct_field_mutation.ig — mutating a field of a value-struct LOCAL
// (`c.n = X`), in the self-hosted C-emit (OFI-054, un-dodged). A value struct is stored as an em_s
// aggregate, so `c.n = X` is a plain C member assign `v0.f{idx} = <rhs>` — a scalar/boxed field takes the
// Value form (emit_value_arg: box a value struct, else a plain read), an inline value-struct field takes the
// raw struct. Previously the field-assign handler only matched an EGet/EIndex object (a boxed parent / array
// element), so a DIRECT value-struct-local write fell through and was SILENTLY DROPPED — every `c.n = …` was
// lost. Now it mutates in place; reading the old field in the new value works (`c.n = c.n + 5`).
// Run-identical to the VM (a value-struct scalar field read skips stage-0's no-op retain-dance — the
// established value-struct divergence). Returns c.n + q.x + q.y = 15 + 3 + 40 = 58.
struct Counter {
    n: int
}


struct Pt {
    x: int
    y: int
}


fn main() -> int {
    var c = Counter { n: 0 }
    c.n = 10                       // direct member assign — was silently dropped
    c.n = c.n + 5                  // read the old field in the new value → 15
    var q = Pt { x: 1, y: 2 }
    q.x = 3                        // mutate one field, leave the other
    q.y = q.y * 20                 // 40
    println("c={c.n} q=({q.x},{q.y})")
    return c.n + q.x + q.y         // 15 + 3 + 40 = 58
}
