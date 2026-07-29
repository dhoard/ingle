// tests/selfhost/codegen_run/iface_impl_method_arg.ig — a value-struct argument to an INTERFACE-IMPL method's
// Self-typed param (`a.compare(b)` where `compare(self, other: Version)` implements Ord) — OFI-224 VM-parity. An
// interface-impl method takes its Self-typed struct param BOXED (the witness convention, so it can be dispatched
// through a vtable), so the arg must be BOX_STRUCT'd at the call site. The self-hosted VM backend passed the
// struct's raw leaf slots (compare's body reads `other` via GET_FIELD off a box) → mismatch/segfault. The method
// param-erasure table now also runs for iface-impl structs, marking a Self-typed struct param boxed ('1') so
// gen_one_arg_e boxes the value-struct arg. RUN-identity fixture. Runs to compare(5,4)=1, compare(4,5)=-1 -> 1 + (-1) + 2 = 2.
interface Ord {
    fn compare(self, other: Self) -> int
}


struct Version implements Ord {
    major: int


    fn compare(self, other: Version) -> int {
        return self.major - other.major
    }
}


fn main() -> int {
    let a = Version { major: 5 }
    let b = Version { major: 4 }
    return a.compare(b) + b.compare(a) + 2   // 1 + (-1) + 2 = 2
}
