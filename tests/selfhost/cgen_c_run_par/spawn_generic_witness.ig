// tests/selfhost/cgen_c_run_par/spawn_generic_witness.ig — `spawn` of a BOUNDED GENERIC function, self-hosted
// native path (OFI-224 v1.0 cutover). `spawn` shares the direct-call calling convention: a bounded-generic
// target takes hidden LEADING witness args (one per bound). emit_bounded_free_call threads them for a direct
// call, but the self-hosted emit_spawn marshalled only the explicit value args and passed count = argc — so the
// value args landed in the witness slots, the fiber dispatcher read a scalar as an enum witness (and ran past
// the short malloc), and the task SIGSEGV'd. Only the self-hosted native backend was affected (the VM and
// stage-0 native both spawned the full witness-prefixed arg vector). emit_spawn now prepends the witnesses
// (self.res.wit + emit_witness + concrete_type_of_arg), shifting the value args after them and spawning with the
// total count. Output-deterministic (a single returned total, no interleaved prints) so the serial VM and the
// real-threaded native binary agree. RUN-identity vs the VM. Runs to 1.
fn tally<K: Hash + Eq>(ch: Channel<int>, a: K, b: K) {
    var n = 0
    if a.eq(b) {
        n = 1                       // witness-dispatched eq on the fiber
    }
    send(ch, n)
}


fn main() -> int {
    let ch: Channel<int> = channel(2)
    nursery {
        spawn tally(ch, 5, 5)       // equal   -> 1
        spawn tally(ch, 7, 9)       // unequal -> 0
    }
    var total = 0
    var got = 0
    loop {
        if got == 2 {
            break
        }
        match recv(ch) {
            case Some(x) {
                total = total + x
                got = got + 1
            }
            case None {
                break
            }
        }
    }
    return total                    // 1 + 0 = 1
}
