// DSP Phase 1: a `mut s: Slice<T>` parameter WRITES THROUGH to the array it views (here a sub-range); a plain
// `Slice<T>` stays read-only. Both backends.

fn scale(mut s: Slice<f32>, g: f32) {
    for i in 0..s.len() {
        s[i] = s[i] * g
    }
}
fn peek(s: Slice<f32>) -> f32 {
    return s[0]
}
fn main() -> int {
    var a: [f32] = [f32(1.0), f32(2.0), f32(3.0), f32(4.0)]
    scale(a[1..3], f32(10.0))
    println("{a[0]} {a[1]} {a[2]} {a[3]} {peek(a[2..4])}")
    return 0
}
