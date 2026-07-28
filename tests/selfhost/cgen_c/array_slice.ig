// tests/selfhost/cgen_c/array_slice.ig — zero-copy array slices in the self-hosted C-emit (slices §, OFI-173,
// un-dodged). `arr[lo..hi]` is a borrowed Slice<T> VIEW → em_slice(&g_em, arr, lo, hi) (an EIndex whose index is
// a range, previously "unhandled expression kind"). A slice is array-like: is_array_expr / is_array_ty(Slice<T>)
// make `win.len()`, `win[i]`, `for x in win`, and a `Slice<T>` param resolve; scalar_kind_of returns -1 for a
// range index so `let win = arr[lo..hi]` binds an array, not an int. A slice is owned/dropped like an array (a
// fresh em_slice view) but bound WITHOUT a retain-dance (emit_concat_operand emits the bare em_slice), and a
// slice-of-a-slice works. Byte-identical to stage-0. Returns sum(win) + mid.len() = 90 + 1 = 91.
fn sum(xs: Slice<int>) -> int {          // a Slice PARAM — iterated like an array, no copy
    var t = 0
    for x in xs {
        t = t + x
    }
    return t
}


fn main() -> int {
    let data = [10, 20, 30, 40, 50]
    let win = data[1..4]                 // a borrowed view of [20, 30, 40]
    println("len={win.len()} first={win[0]} last={win[2]} sum={sum(win)}")   // 3 20 40 90
    println("whole={sum(data[0..data.len()])}")   // 150 — a full-array view, no copy
    let mid = win[1..2]                  // a slice OF a slice → [30]
    println("mid={mid[0]} midlen={mid.len()}")    // 30 1
    return sum(win) + mid.len()          // 90 + 1 = 91
}
