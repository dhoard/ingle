// tests/selfhost/cgen_c_run/match_local_container_payload.ig — typing a match-arm payload when the scrutinee
// is a `.get()` on a LOCAL generic-container binding, in the self-hosted C-emit (OFI-202, un-dodged).
// `match arena.get(h) { case Some(q) { q.age } }` where `arena: SlotMap<Vec3>` needs q typed a Vec3 — but the
// concrete payload type only survives in the container's type arg (`Vec3`), and for a LOCAL receiver that type
// was previously lost (recv_container_ty handled only struct-FIELD receivers, via f_ty). Now a binding's full
// declared container type (with args) is recorded on the scope (sc_ctype / binding_container_ty), so
// recv_container_ty resolves an EIdent receiver too and the existing fn_ret_opt_param path types the payload as
// a Vec3 — so `q.x` / `q.y` / `q.z` resolve. Previously they hit "unsupported field access". (A many-element
// SlotMap<rc-struct>, a string payload field, and two distinct container instances still have separate
// native-runtime ownership gaps, so this exercises the TYPING path with a single insert and scalar fields.)
// Run-identical to the VM (erased generic instances — the established cgen_c_run divergence). Returns 3+4+5 = 12.
import "std/slotmap" as sm


rc struct Vec3 { x: int  y: int  z: int }


fn main() -> int {
    var arena = sm.SlotMap<Vec3>{ items: [], gen: [], free: [], count: 0 }
    let h = arena.insert(Vec3 { x: 3, y: 4, z: 5 })
    var out = 0
    match arena.get(h) {                            // arena: SlotMap<Vec3> — a LOCAL container receiver
        case Some(q) {                              // q typed Vec3 from the container's concrete arg
            out = q.x + q.y + q.z                    // scalar fields on the payload resolve
        }
        case None { out = 0 - 1 }
    }
    return out                                      // 12
}
