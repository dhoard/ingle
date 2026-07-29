// tests/selfhost/codegen/sized_numeric_render.ig — unsigned sized-int RENDERING in the self-hosted VM bytecode
// backend (OFI-123 / OFI-224 VM-parity). An INT_VAL is untagged as to signedness, so a u64 renders SIGNED
// unless coerced: (1) an un-annotated `let d = <lit>u64` must carry the literal's suffix width — infer_render_kind
// gained a `case EInt(v, kind)` so d's slot_kind is 7 and `{d}` interpolates unsigned; (2) a DIRECT println of a
// u64 must TO_STRING 7 before CALL_NATIVE (the native default renders signed) — gen_builtin_call now emits it for
// an unsigned sized-int (kind 4..7) print arg. Byte-identical to stage-0 --emit=bytecode.
fn main() {
    let a: u64 = 18446744073709551615        // u64-max, annotated
    let b = 9223372036854775808u64           // 2^63 via suffix, UN-annotated → width from EInt kind
    println("a={a} b={b}")                    // interpolation render
    println(a)                                // direct println of a u64 → TO_STRING 7
}
