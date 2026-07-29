// tests/selfhost/codegen_run/small_struct_fixes.ig — three small VM-backend fixes (OFI-224):
//  (1) a bare struct-returning-call statement (`mk(i)` discarded) whose all-scalar result spreads N leaf slots
//      must POP each — a single POP left N-1 on the stack and desynced everything after (segfault).
//  (2) `let a = p` aliasing a BOXED struct local now binds a boxed struct binding inheriting p's struct type,
//      so `a.field` resolves — it fell through to a scalar binding and hard-failed "untypeable object".
//  (3) an all-scalar struct-array-literal element that is a struct-returning CALL is BOX_STRUCT'd only when the
//      return is all-scalar (a boxed-struct return is already one Value — the gate stops a double-box).
// RUN-identity fixture. Runs to a.x + a.y + sum = 3 + 4 + (10+20+30) = 67.
struct Pt {
    x: int
    y: int
}


fn mk(n: int) -> Pt {
    return Pt { x: n, y: n * 2 }
}


fn main() -> int {
    var p = Pt { x: 3, y: 4 }
    mk(9)                       // (1) discarded multi-slot struct temp — POP both slots
    let a = p                   // (2) alias a boxed struct local; a.x/a.y resolve
    let arr = [mk(10), mk(20), mk(30)]   // (3) array of struct-returning calls (all-scalar -> boxed elements)
    return a.x + a.y + arr[0].x + arr[1].x + arr[2].x   // 3 + 4 + 10 + 20 + 30 = 67
}
