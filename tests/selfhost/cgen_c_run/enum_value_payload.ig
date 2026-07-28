// tests/selfhost/cgen_c_run/enum_value_payload.ig — a VALUE-struct enum payload bound + read back through a
// match, where the binding has NO type annotation (`let opt = Some(Pt { … })`) so the payload struct must be
// inferred from the CONSTRUCTOR VALUE (OFI-173, un-dodged). value_opt_payload_sid records Pt on the `opt`
// binding from `Some(Pt{…})`, so `match opt { case Some(p) { p.x } }` unboxes the boxed payload into an em_s
// and `p.x`/`p.y` resolve as value-struct fields. Previously the annotation was the ONLY payload-typing source,
// so an un-annotated `let` fell through to a bare Value binding and `p.x` errored.
// Run-identical to the VM (the payload is boxed in the enum, unboxed at the read). Returns p.x + p.y = 14.
struct Pt {
    x: int
    y: int
}


fn main() -> int {
    let opt = Some(Pt { x: 5, y: 9 })        // no annotation — payload struct inferred from the value
    match opt {
        case Some(p) {
            println("opt={p.x},{p.y}")       // 5,9
            return p.x + p.y                 // 14
        }
        case None {
            return 0 - 1
        }
    }
}
