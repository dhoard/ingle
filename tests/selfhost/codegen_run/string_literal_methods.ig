// tests/selfhost/codegen_run/string_literal_methods.ig — a built-in string method called DIRECTLY on a string
// LITERAL / interpolation receiver (`"a,b,c".split(",")`, `"37".parse_int()`, `"abc".len()`) — OFI-224 VM-parity.
// expr_type_kind (which re-derives a method-call receiver's static type in the self-hosted VM backend) had no
// EStr case, so a string-literal receiver came back -1 (untypeable) and the string-method dispatch hard-failed
// "method `.split` on an untypeable expression receiver". A string literal / interpolation is now typed -3
// (string). RUN-identity fixture. Runs to 3 (split count) + 37 (parse_int) + 3 ("abc".len()) = 43.
fn main() -> int {
    let parts = "a,b,c".split(",")           // 3 parts
    var n = 0
    match "37".parse_int() {
        case Some(v) { n = v }               // 37
        case None    { n = 0 }
    }
    return parts.len() + n + "abc".len()     // 3 + 37 + 3 = 43
}
