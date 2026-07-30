// tests/selfhost/codegen_run/slice_views.ig — zero-copy slice VIEWS `arr[lo..hi]` + the copying companion
// `arr.slice(lo,hi)` over the VM backend (OFI-224 VM-parity). A slice is NOT a new runtime type: OP_SLICE
// allocates a fresh ObjArray header (borrowed=1) aliasing the source buffer, so every array op works on it.
// The self backend never emitted OP_SLICE (an ERange index fell through gen_expr's default -> malformed) and
// never typed `arr[lo..hi]` / a `Slice<T>` param as array-like, so `win.len()` hard-failed "untypeable
// receiver". Now: gen_expr EIndex emits OP_SLICE for a range index; ty_is_array/elem_ty_of accept Slice<T>
// (param binding); expr_type_kind types a slice as an array; a `let win = a[lo..hi]` binds array-like.
// RUN-identity fixture. Runs to sum(win)=90, whole=150, mid=30, first_n=... , total below.


// A Slice parameter accepts any window of any array, with no copy.
fn sum(xs: Slice<int>) -> int {
    var t = 0
    for x in xs {
        t = t + x
    }
    return t
}


// The copying companion lets a function hand back an owned sub-array.
fn first_n(a: [int], n: int) -> [int] {
    return a.slice(0, n)
}


fn main() -> int {
    let data = [10, 20, 30, 40, 50]

    let win = data[1..4]                          // a VIEW of [20, 30, 40]
    println("len={win.len()} first={win[0]} last={win[2]} sum={sum(win)}")   // 3 20 40 90

    println("whole={sum(data[0..data.len()])}")   // 150 — a full-array view passed straight to a Slice param

    let mid = win[1..2]                           // slice OF a slice -> [30]
    println("mid={mid[0]} midlen={mid.len()}")    // 30 1

    let head = first_n(data, 3)                   // an OWNED copy [10, 20, 30]
    println("head.len={head.len()} head1={head[1]}")   // 3 20

    return sum(win) + head.len()                  // 90 + 3 = 93
}
