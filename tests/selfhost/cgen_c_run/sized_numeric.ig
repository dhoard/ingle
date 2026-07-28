// tests/selfhost/cgen_c_run/sized_numeric.ig — sized-integer storage, rendering and width-aware arithmetic in
// the self-hosted C-emit (OFI-123, un-dodged). A sized-int LOCAL is stored at its declared width (int8_t …
// uint64_t) and its `{x}` interpolation renders at that width — an INT_VAL is untagged as to signedness, so
// the render-kind carries it (an unsigned local prints unsigned; the u64 range reaches 2^64-1). Arithmetic
// takes its runtime num_kind from the operand width, so a u64 sum wraps at 2^64 (exact, not i64 UB) and a
// wrapping_add(u8,u8) wraps at 2^8. Previously ty_scalar_kind knew only int/f32/f64, so every sized int
// mis-stored as int64_t and rendered signed (kind 0), and wrapping_* hardcoded an i64 num_kind.
// Run-identical to the VM (scalar reads skip the no-op retain-dance). Prints the widths, then returns
// (viaArith == umax ? 1 : 0) + wrap = 1 + 4 = 5.
fn main() -> int {
    let e: u8 = 250
    let g: u32 = 4000000000
    let umax: u64 = 18446744073709551615        // 2^64 - 1, renders unsigned
    let half: u64 = 9223372036854775807         // i64-max
    let viaArith = half + half + 1u64           // exactly 2^64-1 — u64 wrap, not i64 overflow
    let wrapped = wrapping_add(u8(250), u8(10))  // 260 mod 256 = 4
    println("e={e} g={g} umax={umax} arith={viaArith} wrap={wrapped}")
    var ok = 0
    if viaArith == umax {
        ok = 1
    }
    return ok + int(wrapped)                      // 1 + 4 = 5
}
