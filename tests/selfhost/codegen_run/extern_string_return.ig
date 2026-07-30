// tests/selfhost/codegen_run/extern_string_return.ig — a `let o = <extern returning string>` binding types o
// as a STRING so `o.len()` / `{o}` resolve (OFI-224 VM-parity). std/proc declares `extern "c" fn proc_stdout(h)
// -> string`; the self backend recorded only an extern's scalar WIDTH in ext_kinds (ty_scalar_kind -> 0 for a
// string), losing the string/array distinction, so `let o = proc_stdout(self.h); o.len()` (inside Run.combined)
// hard-failed "method `.len` on an untypeable receiver". ext_kinds now stores a classified return code (-3
// string / -2 array / else scalar width via extern_ret_code), consulted by expr_ret_kind / expr_is_string.
// RUN-identity fixture (printf output is a stable golden across both backends).
import "std/proc" as proc


fn main() -> int {
    let r = proc.run("printf hello")
    let o = r.out()                 // an extern-string result bound to a let -> must type as string
    println("out=[{o}] len={o.len()} code={r.code()} combined=[{r.combined()}]")
    return o.len()                  // 5
}
