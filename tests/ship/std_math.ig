// std/math (DSP Phase 1): libm through the registry (VM) / direct calls (native), the f32 forms (compute in
// f64, round once — same bits on both backends), constants, helpers, and calling it from `realtime` code.

import "std/math" as m

realtime fn shape(x: f32, drive: f32) -> f32 {
    return m.tanhf(x * drive) * m.clampf(drive, f32(0.0), f32(1.0))
}

fn main() -> int {
    println("{m.sin(m.PI / 2.0)} {m.cosf(f32(0.0))} {m.atan2(1.0, 1.0) * 4.0}")
    println("{shape(f32(0.5), f32(2.0))} {m.db_to_gain(-6.0)} {m.gain_to_db(0.5)}")
    println("{m.lerp(0.0, 10.0, 0.25)} {m.powf(f32(2.0), f32(10.0))} {m.sqrtf(f32(2.0))}")
    return 0
}
