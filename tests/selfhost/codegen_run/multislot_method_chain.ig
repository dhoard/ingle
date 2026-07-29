// tests/selfhost/codegen_run/multislot_method_chain.ig — a method on a value struct that RETURNS a multi-slot
// (all-scalar) struct, bound directly (`let c = a.add(b)`) and CHAINED (`a.scaled(3).add(b)`) — OFI-224 VM-parity.
// A value-struct method's owned-receiver call BOX_STRUCTs its multi-slot result to one box (so the receiver can
// be DROP_UNDER'd from under a single slot); the `let` binding must UNBOX_STRUCT it back into leaf slots. In a
// chain, the inner call's boxed result is the next receiver — the self-hosted backend must NOT re-box it (that
// double-boxed the receiver) and must box the OUTER call's result before its own DROP_UNDER. Mirrors stage-0's
// `CALL; BOX_STRUCT; DROP_UNDER; UNBOX_STRUCT`. RUN-identity fixture (value-struct representation diverges from
// stage-0 --emit=bytecode). Runs to c.sum() + e.sum() = (11+22) + (3+6 +10+20) = 33 + 39 = 72.
struct Pt {
    x: int
    y: int


    fn add(self, o: Pt) -> Pt {
        return Pt { x: self.x + o.x, y: self.y + o.y }
    }


    fn scaled(self, k: int) -> Pt {
        return Pt { x: self.x * k, y: self.y * k }
    }


    fn sum(self) -> int {
        return self.x + self.y
    }
}


fn main() -> int {
    let a = Pt { x: 1, y: 2 }
    let b = Pt { x: 10, y: 20 }
    let c = a.add(b)               // direct multi-slot method return  -> {11, 22}
    let e = a.scaled(3).add(b)     // chained: scaled -> {3, 6}, then .add(b) -> {13, 26}
    return c.sum() + e.sum()       // 33 + 39 = 72
}
