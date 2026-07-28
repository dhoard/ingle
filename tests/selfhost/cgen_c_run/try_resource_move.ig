// tests/selfhost/cgen_c_run/try_resource_move.ig — `?` on an owning-temp Result MOVES the payload out and
// drops the emptied shell, in the self-hosted C-emit (OFI-122/OFI-173, un-dodged). `let h = acquire(id)?`
// where acquire returns a fresh Result<Handle,_>: the `?` yields the OWNED Handle (a resource struct, boxed,
// drop-bearing) via em_enum_take (not a borrowing em_enum_field) and drops the Result shell, so `h` owns the
// Handle and its scope-exit `drop` fires exactly once. Previously `?` borrowed the payload and never dropped
// the shell, so the resource's drop never ran (a missed drop — an observable VM≠native divergence, since drop
// prints). A BORROWED `?` operand (an Option/Result PARAM) must NOT move+drop — that would free the caller's
// value (a use-after-free) — so the move+drop is gated on recv_is_temp.
// Run-identical to the VM. Prints "use 7" then "drop 7" (scope-exit drop of the moved-out Handle).
resource struct Handle {
    id: int

    fn drop(self) {
        println("drop {self.id}")
    }
}


fn acquire(id: int, ok: bool) -> Result<Handle, string> {
    if !ok {
        return Err("failed")
    }
    return Ok(Handle { id: id })
}


fn use_it(h: Handle) -> int {
    return h.id
}


fn run(ok: bool) -> Result<int, string> {
    let h = acquire(7, ok)?        // ? MOVES the Handle out of the owning-temp Result + drops the shell
    let n = use_it(h)
    println("use {n}")
    return Ok(n)                   // h drops here (reverse order) → "drop 7"
}


fn main() -> int {
    match run(true) {
        case Ok(n)  { return n }   // 7
        case Err(e) { println("err {e}")  return 0 - 1 }
    }
}
