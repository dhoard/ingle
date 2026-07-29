// tests/selfhost/codegen_run/nested_field_append.ig — `arr[i].field.append(x)`: appending to an array FIELD of
// a value-struct element reached through an index (OFI-072 / OFI-224 VM-parity). The INDEX materialises a CLONE
// of the element, so the grown field array must be written back through the nested place — SET_FIELD into the
// element clone, then SET_INDEX into the array — else the append lands on a discarded copy and is lost. The
// self-hosted VM backend's write-back path (place_reads_as_copy + gen_array_append_writeback) now handles the
// EGet(EIndex, field) shape by routing through gen_nested_store. RUN-identity fixture. Runs to
// cs[0].lines.len() + cs[1].lines.len() + cs[0].lines[1].text.len() = 2 + 1 + 5 = 8.
struct Msg {
    role: string
    text: string
}


struct Conv {
    lines: [Msg]
}


fn main() -> int {
    var cs: [Conv] = []
    cs.append(Conv { lines: [] })
    cs.append(Conv { lines: [] })
    cs[0].lines.append(Msg { role: "user", text: "hi" })
    cs[0].lines.append(Msg { role: "claude", text: "hello" })   // append through arr[i].field
    cs[1].lines.append(Msg { role: "user", text: "bye" })
    return cs[0].lines.len() + cs[1].lines.len() + cs[0].lines[1].text.len()   // 2 + 1 + 5 = 8
}
