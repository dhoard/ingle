// tests/selfhost/cgen_c_run/generic_param_retain.ig — a generic-struct method that STORES its erased
// type-parameter value must RETAIN it, in the self-hosted C-emit (OFI-205/OFI-053, un-dodged). In
// `Bag<V>.put(value: V)`, V is the OWNER struct's type-parameter — an erased, possibly-heap Value. Storing
// it into the backing array (a container CONSUME) must own_into_slot it (a retain), or the caller's later
// drop of the same object is a use-after-free. The self-hosted emit only marked a param refcounted when its
// type was the FN's OWN generic (f.generics); a generic-struct method's `value: V` is the OWNER's generic,
// so it was stored WITHOUT the retain (an ASan use-after-free the VM never hits). name_is_owner_generic now
// also marks the owner-type-param param refcounted. Exercised with an rc-struct value (refcounted heap).
// Run-identical to the VM. Returns first.age + second.age + bag.count() = 30 + 41 + 2 = 73.
rc struct Person {
    name: string
    age: int
}


struct Bag<V> {
    items: [V]

    fn put(mut self, value: V) {
        self.items.append(value)
    }

    fn count(self) -> int {
        return self.items.len()
    }
}


fn main() -> int {
    var bag = Bag<Person> { items: [] }
    let a = Person { name: "ada", age: 30 }
    let b = Person { name: "linus", age: 41 }
    bag.put(a)                        // a is stored (must be RETAINED) AND still owned by `a`
    bag.put(b)                        // at scope exit a, b AND bag's entries all drop — a double-free
                                      // unless put retained; ASan is the oracle for the retain
    println("a={a.age} b={b.age} n={bag.count()}")   // a, b are concrete Person locals (field access OK)
    return a.age + b.age + bag.count()   // 30 + 41 + 2 = 73
}
