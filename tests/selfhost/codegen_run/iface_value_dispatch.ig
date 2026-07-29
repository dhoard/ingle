// tests/selfhost/codegen_run/iface_value_dispatch.ig — interfaces used as VALUE types (OFI-224 VM-parity). A
// struct that `implements` an interface upcasts to it wherever the interface type is expected, and a method
// call on an interface value dispatches through its vtable (CALL_DYN). The self-hosted VM backend now upcasts
// (gen_iface_coerce / MAKE_DYN) at every interface site — a binding (`let s: Shape = ..`), a RETURN (`-> Shape`,
// via cur_ret_iface), and a FIELD (`hero: Shape`, via a new struct-field type-name table) — and receiver_iface
// resolves an interface value through a call RESULT (allfn_rettype), an interface FIELD (field_iface), and an
// interface-ARRAY element, not only a bare local. RUN-identity fixture. Runs to
// area(let) + make(0) + scene.hero + arr[0] = 4 + 9 + 25 + 1 = 39.
interface Shape {
    fn area(self) -> int
}


struct Sq implements Shape {
    side: int


    fn area(self) -> int {
        return self.side * self.side
    }
}


fn make(n: int) -> Shape {
    return Sq { side: n }          // return-site upcast
}


struct Scene {
    hero: Shape                    // interface-typed field
}


fn measure(s: Shape) -> int {
    return s.area()
}


fn main() -> int {
    let s: Shape = Sq { side: 2 }              // binding-site upcast
    let scene = Scene { hero: Sq { side: 5 } } // field-site upcast
    let arr: [Shape] = [Sq { side: 1 }]        // array-element upcast
    return measure(s) + make(3).area() + scene.hero.area() + arr[0].area()  // 4 + 9 + 25 + 1 = 39
}
