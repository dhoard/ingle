// tests/selfhost/codegen_run/width_cast_wrap.ig — a width CAST feeding a wrapping-arithmetic intrinsic
// (OFI-224 VM-parity). `wrapping_add(u8(250), u8(10))` lowers to `<a> <b> WRAP_ADD <num_kind>`, and the
// num_kind must be the OPERAND width (u8 = 4) so the VM masks the result modulo 2^8 = 4. scalar_kind_of
// walked into the cast ECall `u8(250)` but had no case for a numeric-typename cast → returned 0 (int), so
// the wrap ran at 64-bit width and printed 260. It now reads numeric_typename_kind(name) for the cast.
// RUN-identity fixture. Runs to wrapping_add(u8(250),u8(10))=4, wrapping_sub(u8(5),u8(10))=251,
// wrapping_mul(u8(200),u8(2))=144 (400 mod 256).
fn main() -> int {
    let a = wrapping_add(u8(250), u8(10))     // 260 mod 256 = 4
    let b = wrapping_sub(u8(5), u8(10))       // -5 mod 256 = 251
    let c = wrapping_mul(u8(200), u8(2))      // 400 mod 256 = 144
    println("a={a} b={b} c={c}")
    return int(a)                              // 4
}
