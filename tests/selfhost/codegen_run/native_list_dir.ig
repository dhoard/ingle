// tests/selfhost/codegen_run/native_list_dir.ig — the `list_dir(path) -> string` native builtin
// (NATIVE_LIST_DIR = 25) over the VM backend (OFI-224 VM-parity). list_dir was absent from the
// self-hosted native_id_for_name and native_ret_kind tables, so `list_dir(..)` emitted no CALL_NATIVE
// operand and its string result was untypeable — `list_dir(..).split("\n").len()` hard-failed "method
// `.len` on an untypeable receiver". Both tables now carry it (id 25, return -3). RUN-identity fixture:
// the --run-bytecode output must equal --emit=run regardless of the directory's actual contents, since
// both walk the SAME checked-in golden tree (tests/run/list_dir_fixture).
fn main() -> int {
    let listing = list_dir("tests/run/list_dir_fixture")
    let n = listing.split("\n").len()      // one entry per line
    println("entries={n} nonempty={listing.len() > 0}")
    println(list_dir("tests/run/no_such_fixture_dir"))   // missing dir -> "" (degrades, no crash)
    return 0
}
