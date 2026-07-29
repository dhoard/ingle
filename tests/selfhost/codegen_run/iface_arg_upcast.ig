// tests/selfhost/codegen_run/iface_arg_upcast.ig — passing a struct where an INTERFACE param is expected
// (`describe(Circle{..})` with `describe(s: Shape)`) must UPCAST the struct to a boxed {receiver, vtable}
// interface value at the CALL SITE, so the callee's `s.method()` dispatches via CALL_DYN (OFI-224 VM-parity).
// The self-hosted VM backend passed the struct's raw fields (no MAKE_DYN), so dispatch went through an absent
// vtable → segfault. A new all-fns param-type table (allfn_ptypes, threaded via WitInfo) lets a non-generic call
// site see that a param is an interface and gen_iface_coerce the struct arg. RUN-identity fixture. Runs to
// area(Sq{4}) + area(Rect{3,5}) = 16 + 15 = 31.
interface Shape {
    fn area(self) -> int
}


struct Sq implements Shape {
    side: int


    fn area(self) -> int {
        return self.side * self.side
    }
}


struct Rect implements Shape {
    w: int
    h: int


    fn area(self) -> int {
        return self.w * self.h
    }
}


fn area_of(s: Shape) -> int {
    return s.area()          // dynamic dispatch through the interface param
}


fn main() -> int {
    return area_of(Sq { side: 4 }) + area_of(Rect { w: 3, h: 5 })   // 16 + 15 = 31
}
