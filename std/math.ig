// std/math — the C maths library, callable from `realtime` code. The f64 functions are libm itself (the
// hosted FFI registry, so they run on the bytecode VM AND native — and native lowers them to direct libm
// calls); the f32 forms compute in f64 and round ONCE, so they give the same bits on every backend and
// platform. Plus the constants and the few helpers every DSP / graphics program writes by hand. DEFAULT
// build — no dependency, no build flag. (DSP Phase 1, docs/design/dsp-plugins.md.)
extern "c" {
    realtime fn sin(x: float) -> float
    realtime fn cos(x: float) -> float
    realtime fn tan(x: float) -> float
    realtime fn asin(x: float) -> float
    realtime fn acos(x: float) -> float
    realtime fn atan(x: float) -> float
    realtime fn atan2(y: float, x: float) -> float
    realtime fn exp(x: float) -> float
    realtime fn log(x: float) -> float
    realtime fn log2(x: float) -> float
    realtime fn log10(x: float) -> float
    realtime fn sinh(x: float) -> float
    realtime fn cosh(x: float) -> float
    realtime fn tanh(x: float) -> float
    realtime fn cbrt(x: float) -> float
    realtime fn trunc(x: float) -> float
    realtime fn hypot(x: float, y: float) -> float
    realtime fn fmod(x: float, y: float) -> float
}


let PI: float = 3.141592653589793
let TAU: float = 6.283185307179586
let E: float = 2.718281828459045


// sinf is sin for an f32: computed in f64, rounded once.
realtime fn sinf(x: f32) -> f32 {
    return f32(sin(f64(x)))
}


// cosf is cos for an f32.
realtime fn cosf(x: f32) -> f32 {
    return f32(cos(f64(x)))
}


// tanf is tan for an f32.
realtime fn tanf(x: f32) -> f32 {
    return f32(tan(f64(x)))
}


// tanhf is tanh for an f32 — the classic soft-clip saturator.
realtime fn tanhf(x: f32) -> f32 {
    return f32(tanh(f64(x)))
}


// expf is exp for an f32.
realtime fn expf(x: f32) -> f32 {
    return f32(exp(f64(x)))
}


// logf is the natural log for an f32.
realtime fn logf(x: f32) -> f32 {
    return f32(log(f64(x)))
}


// sqrtf is the square root of an f32.
realtime fn sqrtf(x: f32) -> f32 {
    return f32(sqrt(f64(x)))
}


// powf raises an f32 to an f32 power.
realtime fn powf(x: f32, y: f32) -> f32 {
    return f32(pow(f64(x), f64(y)))
}


// atan2f is atan2 for f32s.
realtime fn atan2f(y: f32, x: f32) -> f32 {
    return f32(atan2(f64(y), f64(x)))
}


// clamp limits x to [lo, hi].
realtime fn clamp(x: float, lo: float, hi: float) -> float {
    if x < lo {
        return lo
    }
    if x > hi {
        return hi
    }
    return x
}


// clampf limits an f32 to [lo, hi].
realtime fn clampf(x: f32, lo: f32, hi: f32) -> f32 {
    if x < lo {
        return lo
    }
    if x > hi {
        return hi
    }
    return x
}


// lerp blends from a (t = 0) to b (t = 1).
realtime fn lerp(a: float, b: float, t: float) -> float {
    return a + (b - a) * t
}


// lerpf blends two f32s.
realtime fn lerpf(a: f32, b: f32, t: f32) -> f32 {
    return a + (b - a) * t
}


// db_to_gain converts decibels to a linear amplitude factor (-6 dB ≈ 0.501).
realtime fn db_to_gain(db: float) -> float {
    return pow(10.0, db / 20.0)
}


// gain_to_db converts a linear amplitude factor to decibels (0 → -inf).
realtime fn gain_to_db(g: float) -> float {
    return 20.0 * log10(g)
}
