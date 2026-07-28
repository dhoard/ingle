// tests/selfhost/cgen_c_run/packable_string_field_array.ig — an array of a struct that has a STRING field is
// PACKED (inline), not boxed, in the self-hosted C-emit (OFI-061, un-dodged). A struct like `Cell{tag: string,
// n: int}` is inline-PACKABLE (a fixed shape — no array / nested-boxed field) even though it is not a pass-by-
// VALUE struct (the heap string field disqualifies is_value). The array-literal emit packed only value structs
// (struct_sid_of, which gates on is_value), so `[Cell]` fell to a boxed em_array; then `arr[i].field = v`
// mutated a transient em_index copy whose write-back was lost. Now a non-value-but-inline-packable element is
// packed into an em_struct_array (elements emitted directly as boxed em_struct), so `arr[i]` materialises a
// boxed copy and `arr[i].field = v` writes it back (the RMW field-assign). is_value itself is unchanged, so
// pass-by-value signatures are unaffected.
// Run-identical to the VM. Returns cs[0].n + cs[2].n + cs[0].tag.len() = 110 + 130 + 2 = 242.
struct Cell {
    tag: string
    n: int
}


fn main() -> int {
    var cs: [Cell] = [
        Cell { tag: "a", n: 1 },
        Cell { tag: "bb", n: 2 },
        Cell { tag: "c", n: 3 }
    ]
    cs[0].n = 10                 // scalar field write through an index — must write back (RMW)
    cs[2].n = 30
    cs[0].tag = "AA"             // heap-field write through an index — the old "a" released once
    var i = 0
    loop {
        if i == cs.len() {
            break
        }
        cs[i].n = cs[i].n + 100  // read-modify-write in a loop
        i = i + 1
    }
    println("c0={cs[0].tag}:{cs[0].n} c1={cs[1].tag}:{cs[1].n} c2={cs[2].tag}:{cs[2].n}")
    return cs[0].n + cs[2].n + cs[0].tag.len()   // 110 + 130 + 2 = 242
}
