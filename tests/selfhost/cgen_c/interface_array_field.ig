// tests/selfhost/cgen_c/interface_array_field.ig — the [Interface] ARRAY and interface struct FIELD widening
// sites of interface dynamic dispatch, in the self-hosted C-emit (OFI-013, un-dodged). `let shapes: [Shape] =
// [Circle{…}, Square{…}]` upcasts EACH struct element to an interface value (emit_iface_array) and records the
// binding's element interface (sc_elem_iface), so a for-loop var `for sh in shapes` and `shapes[i]` dispatch
// dynamically; and `Scene { hero: Square{…} }` where `hero: Shape` upcasts the struct field value at construction
// (emit_field_consume), so `scene.hero.area()` dispatches through the field's vtable. Byte-identical to stage-0.
// Returns (4+9+16) + 4 + 25 = 58.
interface Shape {
    fn area(self) -> int
}


struct Circle implements Shape {
    r: int

    fn area(self) -> int {
        return self.r * self.r
    }
}


struct Square implements Shape {
    side: int

    fn area(self) -> int {
        return self.side * self.side
    }
}


struct Scene {
    hero: Shape
}


fn main() -> int {
    let shapes: [Shape] = [Circle { r: 2 }, Square { side: 3 }, Circle { r: 4 }]   // element upcast
    var total = 0
    for sh in shapes {
        total = total + sh.area()          // loop var dispatched dynamically → 4 + 9 + 16
    }
    total = total + shapes[0].area()       // index dispatch → 4
    let scene = Scene { hero: Square { side: 5 } }   // interface field upcast
    total = total + scene.hero.area()      // field dispatch → 25
    return total                            // 29 + 4 + 25 = 58
}
