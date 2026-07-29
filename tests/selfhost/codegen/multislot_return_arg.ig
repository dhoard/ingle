// tests/selfhost/codegen/multislot_return_arg.ig — multi-slot (all-scalar) value structs across the RETURN and
// CALL-ARG boundaries in the self-hosted VM bytecode backend (OFI-224 VM-parity). An all-scalar struct occupies
// N exploded stack slots; codegen lost that width in two places: (a) `return p` for a bare struct local/param
// pushed ONE GET_LOCAL under RETURN_STRUCT N — now spreads all N leaf slots; (b) a struct-LITERAL call arg
// (`take(Pt{9,1})`) counted as 1 slot while gen_expr spreads N → CALL arity under-count — now counted by
// struct_field_count. Byte-identical to stage-0 --emit=bytecode.
struct Pt {
    x: int
    y: int
}


fn echo(p: Pt) -> Pt {
    return p                       // bare multi-slot param returned → spread N leaf slots
}


fn take(p: Pt) -> int {
    return p.x + p.y
}


fn main() -> int {
    let a = echo(Pt { x: 3, y: 4 })       // struct-literal arg → N slots; multi-slot return
    return a.x + a.y + take(Pt { x: 9, y: 1 })   // 3+4 + 10 = 17
}
