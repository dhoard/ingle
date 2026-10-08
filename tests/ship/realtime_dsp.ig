// native-only (calls a direct extern, tanhf, which the bytecode VM has no binding for)
// DSP Phase 1: `realtime` code that the checker proves allocation-free — nested filter state updated through
// `self.lp.tick(x)` (OFI-233), a direct libm extern vouched `realtime` (OFI-232), number-array reads/writes.

let TAU: float = 6.283185307179586

extern "c" {
    realtime fn tanhf(x: f32) -> f32
}

struct Biquad {
    b0: f32
    b1: f32
    b2: f32
    a1: f32
    a2: f32
    z1: f32
    z2: f32

    realtime fn tick(mut self, x: f32) -> f32 {
        let y = self.b0 * x + self.z1
        self.z1 = self.b1 * x - self.a1 * y + self.z2
        self.z2 = self.b2 * x - self.a2 * y
        return y
    }
}

struct Engine {
    lp: Biquad
    drive: f32
    gains: [f32]

    realtime fn process(mut self, mut buf: [f32]) {
        for i in 0..buf.len() {
            let s = self.lp.tick(buf[i]) * self.gains[0]
            buf[i] = tanhf(s * self.drive)
        }
        assert(self.drive > f32(0.0), "drive must be positive")
    }
}

realtime fn soft(x: f32) -> f32 {
    if x > f32(1.0) {
        return f32(1.0)
    }
    return x - x * x * x / f32(3.0)
}

fn main() -> int {
    var e = Engine { lp: Biquad { b0: f32(0.2), b1: f32(0.4), b2: f32(0.2), a1: f32(-0.3), a2: f32(0.1), z1: f32(0.0), z2: f32(0.0) }, drive: f32(2.0), gains: [f32(0.5)] }
    var buf: [f32] = [f32(0.1), f32(0.5), f32(-0.3), f32(0.9)]
    e.process(buf)
    println("{buf[0]} {buf[1]} {buf[2]} {buf[3]} {soft(f32(0.5))}")
    return 0
}
