// tests/selfhost/codegen_run/hof_struct_and_enum_payload.ig — two erased-context value-struct typing paths
// (OFI-224 VM-parity), the last pieces of the non-flat-struct cluster:
//   * a HOF-inferred lambda param: `spanned(|sg| sg.b.x - sg.a.x, Seg{..})` where spanned<T>(f: fn(T)->int,
//     x: T) infers T = Seg from the value arg. The lambda param sg was untyped -> `sg.b.x` hard-failed. New
//     compute_hof_lambda_ptys (the struct twin of compute_hof_lambda_str) threads the source arg's struct type
//     to the lifted lambda via pending_lambda_ptys — wired into BOTH the bare-free-call and module-qualified
//     HOF call sites (the bare path never set the lambda annotations at all).
//   * an enum-payload nested struct: `let opt = Some(Pt{..})` then `case Some(p) { p.x }`. A no-annotation
//     enum-construction binding now records its payload STRUCT type (ctor_payload_struct_name) in the erecv
//     table, so subject_prelude_payload_code types p as Pt.
// RUN-identity fixture. Runs to spanned(...)=7 and opt payload 5,9.
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
    let g = spanned(|sg| sg.b.x - sg.a.x, Seg { a: Pt { x: 1, y: 0 }, b: Pt { x: 8, y: 0 } })   // 8 - 1 = 7
    println("g={g}")

    let opt = Some(Pt { x: 5, y: 9 })
    var sum = 0
    match opt {
        case Some(p) {
            println("opt={p.x},{p.y}")   // 5,9
            sum = p.x + p.y              // 14
        }
        case None {
            println("none")
        }
    }
    return g + sum                       // 7 + 14 = 21
}
