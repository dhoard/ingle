// OFI-234: an array LITERAL packs at its elements' known width — f32 conversions, f32 locals, u8 conversions —
// not as i64 (which stored an f32's bits as an integer). Both backends.

fn main() -> int {
    var buf: [f32] = [f32(0.1), f32(0.5)]
    let x = f32(0.75)
    let ys = [x, x]
    var bs: [u8] = [u8(7), u8(9)]
    var fl: [f32] = [0.5, 0.25]
    println("{buf[0]} {buf[1]} {ys[1]} {bs[1]} {fl[1]}")
    return 0
}
