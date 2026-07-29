// tests/selfhost/codegen_run/rc_struct_shared_array.ig — an `rc struct` shared into an array and read back
// (OFI-224 VM-parity). Two bugs, both mirroring stage-0: (1) appending an rc value to an array is a SHARE:
// gen_consume must INCREF a fresh reference (is_rc_struct_read) and leave the source live — the backend was
// MOVING it out (nil the slot), so the second append stranded a nilled value and reading it back segfaulted.
// (2) an rc struct is refcounted -> ALWAYS boxed in an array, never inline-packed even when all-scalar; so
// INDEX of an rc element is a BORROW (GET_FIELD), not an owned clone (GET_FIELD_OWNED) — struct_array_inline
// gained the same kind!=0 guard struct_all_scalar already has, else the borrow was over-released (a trap).
// RUN-identity fixture. Runs to people[0].age + people[1].age + people[2].age = 36+99+36 = 171.
rc struct Name {
    first: string
    last: string
}


rc struct Person {
    name: Name        // an rc field whose type is ANOTHER rc struct
    age: int
}


fn cost(p: Person) -> int {
    return p.age      // pass-by-borrow of a shared rc value
}


fn main() -> int {
    let n  = Name { first: "Ada", last: "Lovelace" }
    let p1 = Person { name: n, age: 36 }     // p1 shares n
    let p2 = Person { name: n, age: 99 }     // p2 shares n too — n now has 3 owners
    let p1b = p1                              // a second owner of p1: incref, not move — p1 stays live
    println("p1={p1.name.first} {p1.age} alias={p1b.age} cost={cost(p2)}")

    var people: [Person] = []
    people.append(p1)
    people.append(p2)
    people.append(p1)                        // p1 shared into the array twice
    var total = 0
    var i = 0
    loop {
        if i == people.len() { break }
        total = total + people[i].age        // INDEX of an rc element is a BORROW -> GET_FIELD
        i = i + 1
    }
    println("len={people.len()} total={total} sample={people[1].name.first}")
    return total                              // 36 + 99 + 36 = 171
}
