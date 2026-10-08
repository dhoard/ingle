// DSP Phase 1: an exported `Slice<number>` crosses as C's (pointer, length) — `mut` = writable in place, plain =
// read-only (`const`). The view's header lives on the wrapper's stack: no allocation, so it is realtime-safe.

struct OnePole {
    a: f32
    z: f32

    realtime fn tick(mut self, x: f32) -> f32 {
        self.z = self.z + self.a * (x - self.z)
        return self.z
    }
}

realtime fn db_gain(db: f32) -> f32 {
    return f32(pow(10.0, f64(db) / 20.0))
}

export "c" realtime fn apply_gain(mut buf: Slice<f32>, db: f32) {
    let g = db_gain(db)
    for i in 0..buf.len() {
        buf[i] = buf[i] * g
    }
}

export "c" realtime fn peak(buf: Slice<f32>) -> f32 {
    var m: f32 = f32(0.0)
    for x in buf {
        if abs(x) > m {
            m = abs(x)
        }
    }
    return m
}
