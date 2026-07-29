// tests/selfhost/codegen_run/qualified_enum_variant.ig — a QUALIFIED zero-field enum variant `Enum.Variant`
// (`Color.Red`, `Option.None`) parses as a bare field access `EGet(EIdent(Enum), Variant)`, NOT a call — so the
// self-hosted VM backend routed it through gen_field_access and hard-failed "field access on an untypeable
// object" (Enum is a type name, not a value). gen_field_access now recognises a qualifier that names an enum and
// a matching zero-field variant, and constructs it as NEW_ENUM (resolve_qual_ctor_vi scopes the variant to its
// enum). RUN-identity fixture. Runs to rank = 3 (Red) - 1 (present via None default) = ... see below: 2 + 0 = 2.
enum Color {
    Red
    Green
    Blue
}


fn rank(c: Color) -> int {
    match c {
        case Red   { return 2 }
        case Green { return 5 }
        case Blue  { return 9 }
    }
}


fn main() -> int {
    let c = Color.Red                 // qualified zero-field variant
    let o: Option<int> = Option.None  // qualified prelude variant, needs the annotation
    var n = 0
    match o {
        case Some(v) { n = v }
        case None    { n = 0 }
    }
    return rank(c) + n                 // 2 + 0 = 2
}
