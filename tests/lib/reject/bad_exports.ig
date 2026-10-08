// Every `export "c"` the checker must refuse (DSP Phase 1).
export "c" fn takes_string(s: string) -> int {
    return s.len()
}
export "c" fn generic<T>(x: T) -> int {
    return 0
}
export "c" fn main() -> int {
    return 0
}
export "rust" fn other() {
}
export "c" fn returns_arr() -> [f32] {
    return []
}
export "c" fn mut_param(mut x: int) -> int {
    return x
}
export "c" fn move_scalar(move x: int) -> int {
    return x
}
// `export` / `realtime` stay ordinary identifiers outside the modifier position
fn names_ok() -> int {
    let export = 3
    let realtime = 4
    return export + realtime
}
