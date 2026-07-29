// tests/selfhost/codegen_run/resource_drop.ig — a `resource struct`'s `drop` method is invoked on scope
// exit / overwrite / return (RAII, OFI-122) over the VM backend (OFI-224 VM-parity). The self-hosted
// SERIALIZER stubbed every struct descriptor's flags + drop_fn as 0/-1, so the loaded bytecode had no
// is_resource bit and no drop-fn index — OP_DROP became a no-op and every "drop N" line went missing.
// emit_one_struct now writes the real flags (is_rc | is_resource<<1) from the struct kind and the
// `{name}.drop` fn-index. RUN-identity fixture. Prints each drop as it happens (order matters).
resource struct R {
    id: int

    fn drop(self) {
        println("drop {self.id}")
    }
}


fn reassign() {
    var r = R { id: 1 }
    r = R { id: 2 }          // R{1} drops here, on the overwrite
    println("after reassign")
}                            // R{2} drops at scope exit


fn two() {
    let a = R { id: 10 }
    let b = R { id: 20 }
    println("two live")
}                            // reverse order: b (20) then a (10)


fn main() -> int {
    reassign()               // drop 1 / after reassign / drop 2
    two()                    // two live / drop 20 / drop 10
    let z = R { id: 99 }
    println("main end")
    return 0                 // drop 99
}
