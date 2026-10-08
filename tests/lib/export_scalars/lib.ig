// `export "c"` + `inglec --emit=lib` (DSP Phase 1): C calls Ingle by name. Each export's C signature is
// built from its Ingle one — scalars at their natural C width, bool as _Bool, Ptr as void*.

fn db_to_gain(db: f32) -> f32 {
    return f32(pow(10.0, f64(db) / 20.0))
}


export "c" fn gain_sample(x: f32, db: f32) -> f32 {
    return x * db_to_gain(db)
}


export "c" fn add_i32(a: i32, b: i32) -> i32 {
    return a + b
}


export "c" fn mix_u8(a: u8, b: u8) -> u8 {
    return (a & 15) | (b & 240)
}


export "c" fn is_loud(x: f64) -> bool {
    return x > 0.5
}


// `move` on a Ptr: C hands the handle over; returning it hands it back
export "c" fn same_handle(move p: Ptr) -> Ptr {
    return p
}


export "c" fn ping() {
    println("ping from Ingle")
}


// a non-exported helper and an internal `main` stay private to the library
fn main() -> int {
    return 7
}
