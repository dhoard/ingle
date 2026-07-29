// tests/selfhost/codegen_run/nested_array_empty_append.ig — appending an empty `[]` to a nested-array
// LOCAL `[[string]]` (OFI-072 / OFI-224 VM-parity). `grid.append([])` on a plain-local receiver went
// through the EIdent array-method branch, which created the inner array with the DEFAULT int element
// AEK — so `grid[i].append("x")` packed the string into an int-typed buffer and `grid[i][j]` read back
// a raw pointer (rendered as a large integer, not the string). The EIdent append branch now, for an
// empty `[]` appended to a nested-array receiver, creates the inner NEW_ARRAY with the receiver's
// 2nd-level element AEK (slot_elem2), mirroring the non-identifier-receiver branch. RUN-identity fixture.
fn main() -> int {
    var grid: [[string]] = []
    grid.append([])
    grid.append([])
    grid[0].append("a")
    grid[0].append("b")
    grid[1].append("c")
    // the read must yield the actual STRINGS, not raw pointers rendered as ints
    println("g0={grid[0][0]},{grid[0][1]} g1={grid[1][0]} lens={grid[0].len()},{grid[1].len()}")

    // a nested INT grid still works (the width path, not just strings)
    var nums: [[int]] = []
    nums.append([])
    nums[0].append(7)
    nums[0].append(8)
    println("n={nums[0][0]}+{nums[0][1]}={nums[0][0] + nums[0][1]}")
    return grid[0].len() + grid[1].len()   // 2 + 1 = 3
}
