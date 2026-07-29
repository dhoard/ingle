// tests/selfhost/codegen_run/struct_local_elem_payload.ig — a multi-slot value-struct LOCAL crossing into boxed
// territory as an inline-ARRAY element (`[v, ..]`) or an enum PAYLOAD (`Some(v)`) — OFI-224 VM-parity. Both
// contexts take one boxed Value per struct, so a multi-slot struct local must be spread to its N leaf slots then
// BOX_STRUCT'd — the backend was pushing its raw fields (NEW_STRUCT_ARRAY / NEW_ENUM read the wrong stack shape
// → corruption). Also array_elem_struct_sid now recognises a struct-local element so `[v, ..]` types as `[V]`
// and `arr[i].field` resolves. RUN-identity fixture. Runs to arr[0].x + arr[1].z + first(Some(v)) = 1 + 6 + 6 = 13.
struct V {
    x: int
    y: int
    z: int
}


fn first(o: Option<V>) -> int {
    match o {
        case Some(q) { return q.x + q.y + q.z }
        case None    { return 0 }
    }
}


fn main() -> int {
    let v = V { x: 1, y: 2, z: 3 }
    let arr = [v, V { x: 4, y: 5, z: 6 }]   // a struct LOCAL element + a literal -> [V], each boxed
    let viaOpt = first(Some(v))             // a struct LOCAL as an enum payload -> boxed
    return arr[0].x + arr[1].z + viaOpt     // 1 + 6 + 6 = 13
}
