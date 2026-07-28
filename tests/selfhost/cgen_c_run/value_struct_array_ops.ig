// tests/selfhost/cgen_c_run/value_struct_array_ops.ig — arrays of VALUE structs in the self-hosted C-emit
// (OFI-054, un-dodged). A packed value-struct array stores each element BOXED, so:
//   - `arr.remove_last()` / `arr.remove_at(i)` return the element as a BOXED Value → binding it to a
//     value-struct local must UNBOX (object_is_value_read gained these method-call cases); previously it
//     bound `em_s0 v = em_array_pop(…)` (a Value into an em_s) and would not compile.
//   - `for e in arr` binds each element as a boxed materialised copy, so `e.field` reads via em_enum_field
//     (the loop var is marked boxed-vstruct), not a `.fN` value read — previously `e.f0` on a Value.
// Run-identical to the VM (boxed materialisation + no-op retain-dance divergence). Returns
// (last.x+last.y) + total(sum a.x over [{1,2},{3,4}]) + pts[1].y = 11 + 4 + 4 = 19.
struct Pt {
    x: int
    y: int
}


fn main() -> int {
    var pts = [Pt { x: 1, y: 2 }, Pt { x: 3, y: 4 }]
    pts.append(Pt { x: 5, y: 6 })
    let last = pts.remove_last()          // {5,6} — a BOXED element unboxed into a value-struct local
    var total = 0
    for a in pts {                        // each `a` is a boxed value-struct copy → a.x via em_enum_field
        total = total + a.x
    }
    println("last=({last.x},{last.y}) total={total} idx={pts[1].y}")
    return last.x + last.y + total + pts[1].y   // 11 + 4 + 4 = 19
}
