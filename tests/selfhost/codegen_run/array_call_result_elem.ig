// tests/selfhost/codegen_run/array_call_result_elem.ig — an unannotated array literal whose elements are
// struct-returning CALL results (`[mk(..), mk(..)]`, not struct literals) must record the element STRUCT id,
// so a later `arr[i].field` (and a nested `arr[i].b.x`) types its receiver (OFI-224 VM-parity). The self-hosted
// VM backend inferred the element kind only from a struct LITERAL element (struct_value_info); a call element
// left the array element untypeable and `arr[i].b` hard-failed with "field access on an untypeable object".
// array_lit_elem_code now infers via array_elem_struct_sid, which also resolves a struct-returning call's return
// sid. RUN-identity fixture (not byte-identical): codegen.ig keeps nested Pt fields BOXED where stage-0 inlines
// them multi-slot, so the bytecode differs but the RESULT matches. Runs to arr[1].b.x = (5 + 4) = 9.
struct Pt {
    x: int
    y: int
}


struct Line {
    a: Pt
    b: Pt
}


fn make_line(p: Pt) -> Line {
    return Line { a: p, b: Pt { x: p.x + 4, y: p.y } }
}


fn main() -> int {
    let arr = [make_line(Pt { x: 0, y: 0 }), make_line(Pt { x: 5, y: 5 })]
    return arr[1].b.x
}
