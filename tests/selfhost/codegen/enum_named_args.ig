// tests/selfhost/codegen/enum_named_args.ig — named-argument enum construction reordered to declared order in
// the self-hosted VM bytecode backend (OFI-222). A variant may be built with NAMED payload fields in ANY order
// (`Rect(h: 3, w: 4)`); the payloads are pushed in the variant's DECLARED order before NEW_ENUM, so the
// bytecode is identical to a positional build (`Rect(w: 4, h: 3)`) — the reorder stage-0's checker performs,
// done at emit time here since the self-hosted codegen consumes the un-reordered AST. codegen.ig carries the
// payload field NAMES (EnumTable.vf_name) and pushes via name_perm (a permutation of indices). Byte-identical
// to stage-0 `--emit=bytecode`: the reversed `Rect(h: 3, w: 4)` emits `CONST 4; CONST 3; NEW_ENUM` — w before h.
// (Kept minimal — one construction, one call — to avoid orthogonal self-hosted-codegen gaps unrelated to the
// reorder.) Runs to dim(Rect(h:3, w:4)) = w*10 + h = 4*10 + 3 = 43.
enum Shape {
    Rect(w: int, h: int)
}


fn dim(s: Shape) -> int {
    match s {
        case Rect(w, h) { return w * 10 + h }
    }
}


fn main() -> int {
    return dim(Rect(h: 3, w: 4))
}
