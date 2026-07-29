// tests/selfhost/codegen_run/clone_value_and_generic.ig — `.clone()` deep copy (OFI-082) across the VM-backend
// parity cases that broke the self-hosted bytecode emitter (OFI-224):
//   * a plain-local / array BORROW receiver deep-clones via OP_INCREF (own_into_slot);
//   * an INDEX receiver, or a field reached THROUGH an index (`cs[i].field`), already reads as an owned COPY —
//     so NO extra OP_INCREF (expr_reads_as_copy recurses through the index, mirroring stage-0). The backend was
//     emitting a spurious INCREF on the field-of-index case, shifting every following instruction.
//   * a GENERIC-struct clone (`m.clone()` on Box<int>): the binding `n` must inherit m's instance type-args so
//     `n.set(..)` resolves to the SAME monomorphized method, and the pre-pass must NOT register a phantom
//     `Box.clone<int>` instance (clone is an intrinsic with no template body — it would dangle every CALL index).
// RUN-identity fixture. Runs to 1+3+3+2+3 = 12 then the generic line: a=10 b=99 (independent).
struct Box<T> {
    v: T

    fn set(mut self, x: T) {
        self.v = x
    }

    fn get(self) -> T {
        return self.v
    }
}


struct Conv {
    n: int
    msgs: [string]     // an array field => Conv is stored BOXED
}


fn main() -> int {
    // borrow clone of a plain local value-struct
    let c = Conv { n: 1, msgs: ["hi"] }
    let d = c.clone()
    let s1 = d.n                                   // 1

    // array borrow clone — grows independently
    var nums: [int] = [1, 2, 3]
    var cp = nums.clone()
    cp.append(4)
    let s2 = cp.len()                              // 4 -> but we print nums.len()==3

    // INDEX clone (reads as copy, no INCREF)
    var convos: [Conv] = []
    convos.append(Conv { n: 5, msgs: ["a"] })
    convos.append(Conv { n: 6, msgs: ["b", "c"] })
    let e = convos[1].clone()
    let s3 = e.msgs.len()                          // 2 -> but we count via field-of-index below

    // field reached THROUGH an index (`cs[i].field`) — reads as copy, NO extra INCREF
    var both = convos[1].msgs.clone()
    both.append("z")
    let s4 = both.len()                            // 3 (original untouched)

    // GENERIC-struct clone — the copy is fully independent, methods resolve to the same instance
    var m = Box<int> { v: 10 }
    var n = m.clone()
    n.set(99)
    println("s1={s1} nums={nums.len()} conv1={convos[1].n} s4={s4} a={m.get()} b={n.get()}")
    return 0
}
