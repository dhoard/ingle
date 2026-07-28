// tests/selfhost/cgen_c_run/index_field_mutate.ig — appending to / overwriting an ARRAY FIELD reached through
// an array INDEX (`cs[i].items.append(x)`, `cs[i].items = […]`), in the self-hosted C-emit (OFI-072,
// un-dodged). em_index materialises the array element, so a mutation of one of its fields must be written back
// or it is LOST. Two nested read-modify-writebacks:
//   - append: em_index the element → take the field OWNED (em_field_owned) → em_array_append (may GROW the
//     array, returning a new pointer) → em_set_field the grown field back → em_set_index the element back.
//     Previously `cs[i].items.append(x)` appended into a copy the grown pointer never left → the append was lost.
//   - whole-field assign: em_index → em_set_field(field, new array) → em_set_index the element back. Previously
//     `cs[i].items = […]` mutated a transient copy → the overwrite was lost.
// Run-identical to the VM. Returns cs[0].items.len() + cs[1].items.len() = 3 + 1 = 4.
struct Row {
    name: string
    items: [int]
}


fn main() -> int {
    var cs: [Row] = []
    cs.append(Row { name: "a", items: [] })
    cs.append(Row { name: "b", items: [] })
    cs[0].items.append(10)          // append through an indexed element's array field (grows → writeback)
    cs[0].items.append(20)
    cs[1].items.append(30)
    cs[0].items = [1, 2]            // whole-field overwrite through the index (must reset, then keep appending)
    cs[0].items.append(3)
    println("c0={cs[0].items.len()} [{cs[0].items[0]},{cs[0].items[1]},{cs[0].items[2]}] c1={cs[1].items.len()}")
    return cs[0].items.len() + cs[1].items.len()   // 3 + 1 = 4
}
