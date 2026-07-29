// tests/selfhost/codegen_run/boxed_elem_field_store.ig — `arr[i].field = v` where arr's element is a BOXED
// value struct (not inline-packed, because it has an array/string field) — OFI-224 VM-parity. INDEX materialises
// a fresh CLONE of a value-struct element (inline OR boxed), so the field store must SET_FIELD into the clone and
// write the whole clone back with SET_INDEX — else the mutation lands on a discarded copy and is lost. The
// self-hosted VM backend's write-back path was gated on struct_array_inline (inline elements only); it now fires
// for any plain (kind 0) value-struct element. RUN-identity fixture. Runs to convos[0].n + convos[1].n = 9 + 2 = 11.
struct Conv {
    n: int
    msgs: [string]     // an array field => Conv is stored BOXED, not inline-packed
}


fn main() -> int {
    var convos: [Conv] = []
    convos.append(Conv { n: 1, msgs: ["hi"] })
    convos.append(Conv { n: 2, msgs: ["yo", "sup"] })
    convos[0].n = 9                 // field store through an index into a BOXED-element array
    return convos[0].n + convos[1].n   // 9 + 2 = 11 (convos[1] untouched)
}
