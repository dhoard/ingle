// tests/selfhost/cgen_c_run/sized_bitnot.ig — the self-hosted C-emit's unary `~`/`-` must carry the OPERAND'S
// width so a sized-unsigned `~x` masks to its type (OFI-224 v1.0 cutover). em_bitnot / em_neg were emitted
// with a HARDCODED num_kind 0 (i64), so `~zero` on a u8 produced the i64 -1 instead of the width-masked 255
// (native == VM was off by 256 in bitwise.ig). New expr_num_kind threads the operand's scalar kind (lookup_kind
// for a binding), matching stage-0's e->num_kind. RUN-identity vs the VM. Runs to 255 + 250 = 505.
fn main() -> int {
    let zero: u8 = 0
    let a = int(~zero)          // ~0 over 8 bits = 255 (not the i64 -1)

    let five: u8 = 5
    let b = int(~five)          // ~5 over 8 bits = 250

    println("a={a} b={b}")      // 255 250
    return a + b                // 505
}
