// tests/selfhost/cgen_c_run/generic_return_field.ig — field access on a generic free fn's bare-type-param
// return, in the self-hosted C-emit (OFI-202, un-dodged). `max<T: Ord>(move a, move b) -> T` returns T; at a
// call with a Version value-struct arg, T = Version. Two halves were needed:
//   (1) the RETURN: struct_sid_any resolves the call's struct via the determining arg (fn_ret_det_arg), and
//       object_is_value_read / object_is_owning_temp treat the erased boxed result as a value read needing
//       em_unbox_struct before `.n` (call_returns_erased_struct) — previously `.n` hit "unsupported field access".
//   (2) the ARG: a value-struct passed to an erased generic-T param (move OR borrow) is BOXED (em_box_struct) —
//       gen_param_mask now includes move params; the borrow-vs-move drop split moved to arg_owning_temp_p.
// Run-identical to the VM (erased generic instances — the established cgen_c_run divergence). Returns 8+8+3 = 19.
interface Ord {
    fn compare(self, other: Self) -> int
}


struct Version implements Ord {
    n: int

    fn compare(self, other: Version) -> int {
        return self.n - other.n
    }
}


fn max<T: Ord>(move a: T, move b: T) -> T {
    if a.compare(b) >= 0 {
        return a
    }
    return b
}


fn main() -> int {
    let lo1 = Version { n: 3 }
    let hi1 = Version { n: 8 }
    let lo2 = Version { n: 3 }
    let hi2 = Version { n: 8 }
    let a = max(lo1, hi1).n          // 8  — field read off the erased boxed return
    let b = max(hi2, lo2).n          // 8
    let c = Version { n: 3 }
    return a + b + c.n               // 8 + 8 + 3 = 19
}
