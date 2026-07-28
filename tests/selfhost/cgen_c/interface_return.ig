// tests/selfhost/cgen_c/interface_return.ig — interface RETURN + dispatch on an interface-returning CALL, in
// the self-hosted C-emit (OFI-013, un-dodged). A fn declared `-> Shape` UPCASTS a concrete struct it returns to
// an interface value (SReturn upcast, driven by the current fn's cur_ret_iface); and a method call on an
// interface-returning call `make(k).area()` dispatches dynamically (recv_iface resolves the call's interface via
// the per-em_fn res.ret_iface table). Byte-identical to stage-0. Returns 12 + 16 + 12 = 40.
interface Shape {
    fn area(self) -> int
}


struct Circle implements Shape {
    r: int

    fn area(self) -> int {
        return self.r * self.r * 3
    }
}


struct Square implements Shape {
    side: int

    fn area(self) -> int {
        return self.side * self.side
    }
}


fn make(kind: int) -> Shape {          // returns an INTERFACE — the struct is upcast at each return
    if kind == 0 {
        return Circle { r: 2 }
    }
    return Square { side: 4 }
}


fn main() -> int {
    let s: Shape = make(0)             // an interface-returning call bound to an interface local (moved, not re-upcast)
    return make(0).area() + make(1).area() + s.area()   // 12 + 16 + 12 = 40
}
