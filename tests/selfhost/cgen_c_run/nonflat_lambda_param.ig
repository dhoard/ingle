// tests/selfhost/cgen_c_run/nonflat_lambda_param.ig — a lambda param typed as a NON-FLAT struct (a struct with
// nested inline-struct fields) crossing an erased higher-order call (OFI-206, un-dodged). `spanned<T>` is an
// erased generic over T; called `spanned(|sg| sg.b.x - sg.a.x, Seg { … })`, record_hof_lambdas types the lifted
// lambda's param `sg` as Seg from the determining arg. Because Seg is non-flat (a:Pt, b:Pt), the boxed param is
// read with the nested-field discipline: `sg.b` materialises the inner Pt, `.x` reads its scalar — the chained
// read off a boxed non-flat value struct, not a flat `.fN`.
// Run-identical to the VM (the erased lambda param is a boxed Value). Returns dx + dy = (8-1) + (6-0) = 13.
struct Pt {
    x: int
    y: int
}


struct Seg {
    a: Pt
    b: Pt
}


fn spanned<T>(f: fn(T) -> int, x: T) -> int {
    return f(x)
}


fn main() -> int {
    let dx = spanned(|sg| sg.b.x - sg.a.x, Seg { a: Pt { x: 1, y: 0 }, b: Pt { x: 8, y: 0 } })  // 7
    let dy = spanned(|sg| sg.b.y - sg.a.y, Seg { a: Pt { x: 0, y: 0 }, b: Pt { x: 0, y: 6 } })  // 6
    println("dx={dx} dy={dy}")
    return dx + dy                          // 13
}
