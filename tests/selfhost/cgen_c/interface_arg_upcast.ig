// tests/selfhost/cgen_c/interface_arg_upcast.ig — struct→interface ARG upcast, the last interface-dispatch
// widening site, in the self-hosted C-emit (OFI-013, un-dodged). A concrete struct passed directly to an
// interface PARAM (`measure(Sq{…})` where `measure(s: Shape)`) is UPCAST to an interface value at the call
// site (emit_call_arg_gen, driven by a new per-em_fn/per-param res.param_iface table). The upcast produces a
// fresh owned interface temp the callee borrows and the CALLER drops after the call (arg_owning_temp_p), so it
// does not leak. Byte-identical to stage-0. Returns 36 + 49 = 85.
interface Shape {
    fn area(self) -> int
}


struct Sq implements Shape {
    side: int

    fn area(self) -> int {
        return self.side * self.side
    }
}


fn measure(s: Shape) -> int {          // an interface PARAM
    return s.area()
}


fn main() -> int {
    return measure(Sq { side: 6 }) + measure(Sq { side: 7 })   // struct args upcast at the call site: 36 + 49 = 85
}
