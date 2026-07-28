// tests/selfhost/cgen_c_run/container_values_array.ig — element typing of a generic-container method that
// returns `[V]`, in the self-hosted C-emit (OFI-202, un-dodged). `arena.values()` on a SlotMap<Vec2> returns
// [Vec2], but the method's static element struct is erased (V), so `vs[i].x` hit "unsupported field access".
// method_opt_payload_param now also exposes a `[V]` return's owner type-param (disambiguated from the
// Option/Result payload case via fn_ret_array), and value_elem_struct resolves the element from the receiver's
// concrete type-arg (recv_container_ty) — so `let vs = arena.values(); vs[i].x` types the element as Vec2.
// Run-identical to the VM (erased element — the cgen_c_run divergence). One insert to avoid the separate
// SlotMap multi-op native paths. Returns 3 + 4 = 7.
import "std/slotmap" as sm


struct Vec2 { x: int  y: int }


fn main() -> int {
    var arena = sm.SlotMap<Vec2>{ items: [], gen: [], free: [], count: 0 }
    let h = arena.insert(Vec2 { x: 3, y: 4 })
    let vs = arena.values()                     // [Vec2] — element struct resolved from SlotMap<Vec2>
    var total = 0
    var i = 0
    loop {
        if i == vs.len() {
            break
        }
        total = total + vs[i].x + vs[i].y       // vs[i] typed Vec2 → .x / .y resolve
        i = i + 1
    }
    return total                                // 3 + 4 = 7
}
