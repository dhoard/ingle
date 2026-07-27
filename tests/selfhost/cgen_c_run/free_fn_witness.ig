// tests/selfhost/cgen_c_run/free_fn_witness.ig — FREE-FUNCTION bounded-generic WITNESS dispatch in the
// self-hosted C-emit (OFI-174, un-dodged). A free `fn describe<T: Named + Aged>(x)` / `fn pair_sum<A: Aged,
// B: Aged>(p, q)` carries one hidden leading `Value wN` witness param per (type-param, bound); the body's
// `x.name()` / `x.age()` dispatch through the matching witness param (rt_call_indirect on em_enum_field(wN,
// midx)); each call site builds the concrete witness (em_enum of the impl's method fn-ids), threads it as a
// leading arg, and drops it after. Method count/index come from the user DInterface decls. Previously
// `x.name()` hit "unresolved callee" (the witness path only handled struct methods via self's field).
// Run-identical to the VM (NOT byte-identical: stage-0 hoists args into temps and its erased-generic ownership
// differs). Prints Ada / age=36 / pair=15.
interface Named {
    fn name(self) -> string
}


interface Aged {
    fn age(self) -> int
}


struct Person implements Named, Aged {
    pname: string
    years: int

    fn name(self) -> string {
        return self.pname
    }
    fn age(self) -> int {
        return self.years
    }
}


fn describe<T: Named + Aged>(x: T) -> int {          // one type-param, TWO bounds -> two witness params w0, w1
    println("{x.name()}")                            // dispatches through w0 (Named)
    return x.age()                                   // ...and w1 (Aged)
}


fn pair_sum<A: Aged, B: Aged>(p: A, q: B) -> int {   // TWO type-params -> two witness params (one each)
    return p.age() + q.age()
}


fn main() {
    let ada = Person { pname: "Ada", years: 36 }
    let r = describe(ada)                            // call site threads the Person witness(es)
    println("age={r}")
    let a = Person { pname: "x", years: 10 }
    let b = Person { pname: "y", years: 5 }
    let s = pair_sum(a, b)
    println("pair={s}")
}
