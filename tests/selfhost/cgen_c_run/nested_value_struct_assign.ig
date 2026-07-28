// tests/selfhost/cgen_c_run/nested_value_struct_assign.ig — in-place mutation of a nested value-struct field
// on a fully-ADDRESSABLE value-struct chain (`f.a.x = X`), in the self-hosted C-emit (OFI-155, un-dodged).
// When the whole object chain is value structs (a flat value-struct local + inline value-struct fields), the
// place emits as a direct C member chain (`v.f0.f1`), so the write is an in-place member assign — NOT the
// boxed unbox-modify-rebox path a boxed parent needs. The self-hosted emit previously ran EVERY `parent.f.g =
// X` through the boxed path (em_enum_field on the parent), which mis-typed a value-struct parent (`Value = em_s`)
// and failed to compile. is_addressable_value_place now routes the addressable chain to the direct assign; a
// whole value-struct field assign (`g.b = Inner{…}`, `g.a = g.b`) takes the raw struct.
// Run-identical to the VM (value-struct field reads skip the no-op retain-dance). Returns
// f.a.x + f.b.y + g.a.x + g.b.y = 99 + 102 + 107 + 8 = 316.
struct Inner {
    x: int
    y: int
}


struct Outer {
    a: Inner
    b: Inner
}


fn main() -> int {
    var f = Outer { a: Inner { x: 1, y: 2 }, b: Inner { x: 3, y: 4 } }
    f.a.x = 99                        // direct member-chain assign v.f0.f0 = 99
    f.b.y = f.a.x + f.b.x             // 99 + 3 = 102

    var g = Outer { a: Inner { x: 1, y: 1 }, b: Inner { x: 2, y: 2 } }
    g.b = Inner { x: 7, y: 8 }        // whole value-struct field assign — raw struct (literal RHS)
    g.a = g.b                         // whole value-struct field assign — value copy (field-read RHS)
    g.a.x = g.a.x + 100               // mutate the copy; g.b stays {7,8}
    println("f=({f.a.x},{f.b.y}) g=(a.x={g.a.x},b.y={g.b.y})")
    return f.a.x + f.b.y + g.a.x + g.b.y   // 99 + 102 + 107 + 8 = 316
}
