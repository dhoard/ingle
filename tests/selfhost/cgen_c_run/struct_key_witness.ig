// tests/selfhost/cgen_c_run/struct_key_witness.ig — struct-WITNESS method dispatch on a match-payload receiver
// in the self-hosted C-emit (OFI-174, un-dodged). Inside std/map + std/set, a bounded type-param key is compared
// via `case Some(k) { if k.eq(key) … }` where k is the Some payload of a `[Option<K>]` field — NOT a `key: K`
// param. The struct-witness dispatch only recognised type-param PARAMS/FIELDS, so `k.eq` hit "unresolved callee".
// A binding whose type is a bounded owner type-param K is now recorded on the scope (sc_tp_tname, via
// match_payload_owner_tparam), so lookup_tp_tname finds it and `k.eq(x)`/`k.hash()` dispatch through self's
// witness field (a DOUBLE em_enum_field) exactly like `key: K`. Run-identical to the VM (erased witness — the
// cgen_c_run divergence; a single insert avoids the separate Map-resize-of-struct-key native path). Returns
// 100 + 200 + 1 = 301 (Pt keys distinguished by the Eq witness; a Set membership hit via the same witness).
import "std/map" as map
import "std/set" as set


struct Pt implements Hash, Eq {
    x: int
    y: int

    fn hash(self) -> int {
        return self.x * 31 + self.y
    }
    fn eq(self, other: Pt) -> bool {
        return self.x == other.x && self.y == other.y
    }
}


fn main() -> int {
    var m = map.Map<Pt, int>{ buckets: [], count: 0 }
    m.set(Pt { x: 1, y: 2 }, 100)
    m.set(Pt { x: 3, y: 4 }, 200)                 // distinct key — the Eq witness keeps them apart
    var t = 0
    match m.get(Pt { x: 1, y: 2 }) { case Some(v) { t = t + v } case None { } }   // +100
    match m.get(Pt { x: 3, y: 4 }) { case Some(v) { t = t + v } case None { } }   // +200

    var s = set.Set<Pt>{ slots: [], count: 0 }
    s.add(Pt { x: 7, y: 8 })
    if s.has(Pt { x: 7, y: 8 }) {                 // membership via the hash + eq witnesses
        t = t + 1
    }
    return t                                       // 301
}
