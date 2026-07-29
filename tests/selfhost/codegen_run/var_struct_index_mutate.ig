// tests/selfhost/codegen_run/var_struct_index_mutate.ig — `var e = arr[i]` copies a struct element out of an
// inline (all-scalar) struct array; a later `e.field = v` must MUTATE that copy (OFI-224 VM-parity). The
// self-hosted VM backend UNBOX_STRUCT'd EVERY struct-index binding into leaf slots — correct for an immutable
// `let` (read-only), but a MULTI-SLOT local has no field-store path, so `e.field = v` on a `var` silently
// emitted nothing and the mutation was lost. The UNBOX is now gated `is_var == false`; a mutable `var` stays
// BOXED (one slot) so the assignment lowers to SET_FIELD — mirrors stage-0 (`INDEX` boxed; `GET_LOCAL; SET_FIELD`).
// The copy is independent of the array: mutating `first` leaves pts[0] untouched. RUN-identity fixture (nested/
// array struct representation diverges from stage-0 --emit=bytecode). Runs to first.x + pts[0].x = 99 + 1 = 100.
struct Pt {
    x: int
    y: int
}


fn main() -> int {
    var pts = [Pt { x: 1, y: 2 }, Pt { x: 3, y: 4 }]
    var first = pts[0]        // a COPY of {1, 2}
    first.x = 99              // mutate the copy; pts[0] stays {1, 2}
    return first.x + pts[0].x // 99 + 1 = 100
}
