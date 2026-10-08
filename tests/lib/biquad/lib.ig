// DSP Phase 1 exit test: a realtime biquad + soft-clip `process()` exported to C. The C host owns the audio
// buffer AND the filter state (two floats it keeps between calls — per-instance plugin state is Phase 2), so
// the filter runs across block boundaries exactly as one continuous call would. Everything on the audio path
// is `realtime`, so the compiler has proven it never allocates.
import "std/math" as m

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


// lowpass: RBJ cookbook coefficients for cutoff `fc` Hz at sample rate `fs`, resonance `q`; filters `buf` in
// place, carrying the two state values in `state` across calls; then soft-clips with tanh.
export "c" realtime fn lowpass(mut buf: Slice<f32>, mut state: Slice<f32>, fs: f32, fc: f32, q: f32) {
    let w0 = m.TAU * f64(fc) / f64(fs)
    let alpha = m.sin(w0) / (2.0 * f64(q))
    let cw = m.cos(w0)
    let a0 = 1.0 + alpha
    var f = Biquad { b0: f32((1.0 - cw) / 2.0 / a0), b1: f32((1.0 - cw) / a0), b2: f32((1.0 - cw) / 2.0 / a0), a1: f32(-2.0 * cw / a0), a2: f32((1.0 - alpha) / a0), z1: state[0], z2: state[1] }
    for i in 0..buf.len() {
        buf[i] = m.tanhf(f.tick(buf[i]))
    }
    state[0] = f.z1
    state[1] = f.z2
}
