// tests/selfhost/cgen_c_run/generic_param_field.ig — field access on a generic-instance value whose type
// arg is a bare TYPE-VARIABLE, in the self-hosted C-emit (OFI-202, un-dodged). Inside `fn unwrap<T>(b: Box<T>)`
// the param type `Box<T>` has no monomorphic entry in the instance table (only concrete `Box<int>` etc. are
// registered), so sid_of_ty falls back to the BASE struct sid — the erased template carries the field layout
// (`value` at index 0) and its boxed representation — and `b.value` resolves to em_enum_field like `Box<int>`.
// Previously `b.value` on a `Box<T>` param hit "unsupported field access". Run-identical to the VM (NOT
// byte-identical: the self-hosted compiler ERASES generic struct instances where stage-0 monomorphises them
// to packed value structs — the established cgen_c_run divergence). Prints 4, 7, then returns 11.
struct Box<T> { value: T }


fn unwrap<T>(b: Box<T>) -> T {          // b: Box<T> — a generic instance with a type-VARIABLE arg
    return b.value                      // em_enum_field(a0, 0) via the base-sid fallback
}


fn first<T>(pair: Pair<T>) -> T {
    return pair.a
}


struct Pair<T> { a: T  b: T }


fn main() -> int {
    let n = unwrap(Box<int> { value: 4 })
    println("{n}")                      // 4
    let s = unwrap(Box<int> { value: 7 })
    println("{s}")                      // 7
    let p = first(Pair<int> { a: 11, b: 99 })
    return p                            // 11
}
