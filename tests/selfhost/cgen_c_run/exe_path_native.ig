// tests/selfhost/cgen_c_run/exe_path_native.ig — the exe_path() native on the self-hosted C-emit backend
// (OFI-224 v1.0 cutover). exe_path() returns the running executable's absolute path (readlink /proc/self/exe
// on Linux, _NSGetExecutablePath on macOS) so an installed self-hosted toolchain can locate its stdlib relative
// to its own binary (<bin>/../std), the frontend-free analog of init_std_dir. The path itself is machine- and
// binary-dependent (the VM returns its interpreter's path, a native binary returns its own), so it can't be
// goldened — but its NON-EMPTINESS and absoluteness are run-identical between the VM and the self-hosted native
// binary on every supported platform. Guards the native's presence + string-return handling end-to-end.
fn main() -> int {
    let p = exe_path()
    var ok = 0
    if p.len() > 0 {
        ok = 1                       // both the VM and a native binary return their own non-empty path
    }
    var absolute = 0
    if char_code(p) == 47 {
        absolute = 1                 // a leading '/' (byte 47) — an absolute path on Linux/macOS
    }
    println("exe_nonempty={ok} absolute={absolute}")
    return ok + absolute             // 2 on a supported platform, run-identical VM vs native
}
