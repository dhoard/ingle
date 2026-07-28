// tests/selfhost/cgen_c/interface_dispatch.ig — interface-as-value DYNAMIC DISPATCH in the self-hosted C-emit
// (OFI-013, un-dodged). A struct that `implements` an interface upcasts to an interface VALUE (a heap
// {receiver, vtable} fat pointer) at a `let s: Interface = Struct{…}` binding — alloc_interface(&g_em, <boxed
// receiver>, <vtable em_enum of the impl's method fn-ids in interface-decl order> = emit_witness). A method call
// on an interface-typed binding/param dispatches at RUN TIME through the vtable: em_invoke on the fn-id read at
// the interface method index. The interface value uniquely OWNS its receiver+vtable (dropped at scope exit) and
// is passed to a callee as a BORROW. Previously any interface use hit "unresolved callee". Byte-identical to
// stage-0. (This fixture covers the let-binding + interface-PARAM + dispatch core; interface returns / fields /
// [Interface] arrays are the remaining widening sites.) Returns 25 + 25 + 9 = 59.
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


fn measure(s: Shape) -> int {          // an interface-typed PARAM — dispatched dynamically
    return s.area()
}


fn main() -> int {
    let a: Shape = Sq { side: 5 }       // upcast at the binding
    let b: Shape = Rect { w: 3, h: 3 }  // a different impl — a different vtable
    return measure(a) + a.area() + measure(b)   // 25 + 25 + 9 = 59
}
