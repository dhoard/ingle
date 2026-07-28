// tests/selfhost/cgen_c_run/generic_param_name_collision.ig — a user struct named exactly like a generic
// type PARAMETER must not collide with it in the self-hosted C-emit's by-name type resolution (OFI-053,
// un-dodged). Inside `Box<T>` the type-param `T` is the ERASED, boxed Value; the same-named user `struct T`
// is unrelated. The self-hosted emit resolved `-> T` / `item: T` / a `item: T` FIELD by name to the user
// struct (a value-struct em_s), so the method C signatures didn't match (a `Value` returned as an `em_s`)
// and it failed to compile. name_is_owner_generic (the sg_owner/sg_tparam struct-generics table) now
// excludes an owner type-param name at the return, param, field and ret-table resolution sites.
// Run-identical to the VM (the erased generic is a boxed Value). Returns box.get() = 42.
struct T {
    n: int
}


struct V {
    tag: int
}


struct Box<T> {
    item: T

    fn set(mut self, item: T) {
        self.item = item
    }

    fn get(self) -> T {
        return self.item
    }
}


struct Pair<K, V> {
    a: K
    b: V

    fn second(self) -> V {
        return self.b
    }
}


fn main() -> int {
    var box = Box<int> { item: 0 }
    box.set(42)
    let pair = Pair<int, string> { a: 1, b: "hi" }
    println("get={box.get()} second={pair.second()}")   // get=42 second=hi
    return box.get()                                     // 42
}
