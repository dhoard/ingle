// tests/selfhost/cgen_c/ffi_struct.ig — FFI structs by value across the C ABI in the self-hosted C-emit (OFI-173,
// un-dodged). An all-scalar Ingle struct passed to / returned from an `extern "c"` fn crosses the boundary as its
// SCALAR LEAVES: a `Vec2` arg becomes `v.f0, v.f1` (bound to an em_s temp, then spliced), and the em_ffi leaf
// count is the total. A struct RETURN passes the return struct sid to em_ffi (rsid, from a new extern_ret_struct
// table) and unboxes the reassembled boxed struct into an em_s (`sum.x` is then a direct member); a scalar return
// keeps rsid = -1. struct_sid_any resolves an extern's return struct so `let sum = cvec2_add(a,b); sum.x` binds a
// value struct. Previously `.x` on an FFI struct return hit "unsupported field access". Byte-identical to stage-0.
// (cvec2_* live in src/cextern.c.) Returns 5 + 11 + 4 + 6 + 6 + 8 = 40.
struct Vec2 {
    x: f64
    y: f64
}


extern "c" {
    fn cvec2_len(v: Vec2) -> f64            // struct arg, scalar return
    fn cvec2_dot(a: Vec2, b: Vec2) -> f64   // two struct args, scalar return
    fn cvec2_add(a: Vec2, b: Vec2) -> Vec2  // struct args AND struct return
    fn cvec2_scale(v: Vec2, k: f64) -> Vec2 // struct + scalar arg, struct return
}


fn main() -> int {
    let a = Vec2 { x: 3.0, y: 4.0 }
    let b = Vec2 { x: 1.0, y: 2.0 }
    let len = cvec2_len(a)                   // 5.0
    let dot = cvec2_dot(a, b)                // 3*1 + 4*2 = 11.0
    let sum = cvec2_add(a, b)                // {4.0, 6.0}
    let scaled = cvec2_scale(a, 2.0)         // {6.0, 8.0}
    let total = len + dot + sum.x + sum.y + scaled.x + scaled.y   // 5+11+4+6+6+8 = 40
    return to_int(total)
}
