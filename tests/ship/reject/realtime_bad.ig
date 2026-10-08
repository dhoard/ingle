// Every construct the realtime checker must refuse (selfhost/realtime.ig) — each named with its line.

fn helper(x: f32) -> f32 {
    return x
}

struct S {
    name: string
    xs: [f32]
    v: f32

    realtime fn bad_method(mut self) {
        self.name = "new"
    }
}

realtime fn bad(x: f32, xs: [f32], names: [string]) -> f32 {
    println("hi {x}")
    let s = "a" + "b"
    var arr: [f32] = []
    arr.append(x)
    let h = helper(x)
    let o = Some(x)
    let n = names[0]
    let w = xs[0..2]
    return h
}

struct Tagged {
    tag: string
    v: f32
}

realtime fn builds_heap_struct(x: f32) -> f32 {
    let t = Tagged { tag: "x", v: x }
    return x
}

realtime fn returns_string() -> string {
    return "no"
}
