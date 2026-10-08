// A slice is a read-only view unless it is a `mut s: Slice<T>` parameter; an `export "c"` Slice must be of numbers.
fn bad_param(s: Slice<f32>) {
    s[0] = f32(1.0)
}

fn bad_local() {
    var a: [f32] = [f32(1.0)]
    let w = a[0..1]
    w[0] = f32(2.0)
}

export "c" fn bad_export(mut names: Slice<string>) {
}

fn main() -> int {
    return 0
}
