// OFI-229 — the native backend's typed-scalar fast path: when both operand types are known scalars,
// arithmetic/compares lower to plain C operators instead of em_add/em_mul/em_lt calls on boxed Values.
// Every result below must match the VM bit-for-bit (this file is a VM-vs-binary differential).

// An f32 biquad: each op must round to f32 once, exactly like the VM's double-op-then-round.
fn biquad(mut buf: [f32], b0: f32, b1: f32, b2: f32, a1: f32, a2: f32) -> f32 {
    var z1: f32 = f32(0.0)
    var z2: f32 = f32(0.0)
    for i in 0..buf.len() {
        let x = buf[i]
        let y = b0 * x + z1
        z1 = b1 * x - a1 * y + z2
        z2 = b2 * x - a2 * y
        buf[i] = y
    }
    return z1
}


// a*b - c where the exact product needs more than 53 bits: unfused it rounds to 1.0 first (result 0),
// a fused multiply-add would give -2^-60. Catches FP contraction sneaking into the emitted C.
fn no_fma(a: float, b: float, c: float) -> float {
    return a * b - c
}


fn widened(x: f32, y: float) -> float {
    return f64(x) * y + -f64(x)      // an f32 widened to f64 (f64(x) of a float lowers inline), plus float negation
}


fn int_ops(a: int, b: int) -> int {
    return (a * b + a / b - a % b) & 1023
}


fn u64_order(a: u64, b: u64) -> bool {
    return a > b
}


fn narrow(a: i32, b: i32) -> i32 {
    return a * b - 7
}


fn main() -> int {
    var buf: [f32] = []
    for i in 0..1000 {
        buf.append(f32(to_float(i % 17) * 0.125 - 1.0))
    }
    let z = biquad(buf, f32(0.2), f32(0.4), f32(0.2), f32(-0.3), f32(0.1))
    println("biquad z1 = {z}, y[999] = {buf[999]}, y[500] = {buf[500]}")

    let e = 1.0 / 1073741824.0
    println("no_fma = {no_fma(1.0 + e, 1.0 - e, 1.0)}")
    println("widened = {widened(f32(1.1), 3.3)}")

    println("int_ops = {int_ops(123456, 789)}, {int_ops(-77, 5)}")
    let big: u64 = 18446744073709551615
    println("u64 order = {u64_order(big, 1)}, {u64_order(1, big)}")
    println("narrow = {narrow(1000, 2000)}")
    println("compare f32 = {f32(0.1) < f32(0.2)}, f64 eq = {0.5 == 0.25 + 0.25}")

    // the fast path must keep the overflow trap: 50000 * 50000 leaves i32
    println("about to overflow")
    println("{narrow(50000, 50000)}")
    return 0
}
