// tests/selfhost/codegen_run/generic_method_value_struct.ig — a GENERIC struct whose method RETURNS and TAKES
// a concrete all-scalar value struct (Handle), over the VM backend (OFI-224 VM-parity; the SlotMap crash).
// A generic-struct method uses the BOXED ABI for value-struct params AND returns (self_type is a generic
// instance, never multislot-eligible), so three sites must agree with stage-0:
//   * put returns Handle BOXED (ret_box_struct) — already correct;
//   * `let h = arena.put(..)` must UNBOX the boxed Handle into its leaf slots (method_call_boxed_result_sid now
//     recognises a boxed GENERIC-struct receiver, keyed on recv_struct_is_generic, using the BASE fn-index);
//   * `arena.at(h)` must pass the Handle arg BOXED + masked as an owning temp (BOX_STRUCT; ...; PICK; CALL;
//     DROP_UNDER) — gen_recv threads recv_struct_is_generic into plan_erased_mask/push_mask_temps.
// The old backend spread the Handle arg multi-slot (CALL arity mismatch) and never unboxed the result -> SIGSEGV.
// RUN-identity fixture. Runs to at(put(10)) + at(put(20)) + h0.idx + h1.idx = 10 + 20 + 0 + 1 = 31.
struct Handle {
    idx: int
    gen: int
}


struct Arena<T> {
    items: [T]                 // a heap field => Arena is stored BOXED (the generic-container shape)
    count: int

    fn put(mut self, v: T) -> Handle {
        self.items.append(v)
        self.count = self.count + 1
        return Handle { idx: self.items.len() - 1, gen: 7 }
    }

    fn at(self, h: Handle) -> T {
        return self.items[h.idx]
    }

    fn size(self) -> int {
        return self.count
    }
}


fn main() -> int {
    var arena = Arena<int> { items: [], count: 0 }
    let h0 = arena.put(10)     // returns Handle BOXED -> binding UNBOXes to {idx, gen} leaf slots
    let h1 = arena.put(20)
    let a = arena.at(h0)       // Handle arg BOXED + PICK/DROP_UNDER dance
    let b = arena.at(h1)
    println("a={a} b={b} h0={h0.idx} h1={h1.idx} gen={h0.gen} size={arena.size()}")
    return a + b + h0.idx + h1.idx   // 10 + 20 + 0 + 1 = 31
}
