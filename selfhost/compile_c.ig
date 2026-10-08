// selfhost/compile_c.ig — the self-hosted CHECKED C-emit compiler (OFI-224 G4). It is cgen_c_dump.ig's
// load-and-emit path (BFS module load + prelude injection + selfhost/cgen_c.ig C-emit) with the
// selfhost/checker.ig type-check gate from emberc.ig fused IN FRONT: an ill-typed program is REJECTED with
// exit 65 (stage-0's check-error code) instead of emitting garbage C. This is the driver destined to be the
// default `inglec` — `cgen_c_dump.ig` stays the untyped byte-identical differential driver, this one is the
// safe compiler. (The load_modules machinery is duplicated from cgen_c_dump.ig for now; consolidating the
// two drivers into one flag-dispatched front end is later cutover work — Fork 2.)
//
//   inglec -o inglec-self selfhost/compile_c.ig   →   ./inglec-self <file.ig>   # checked Ingle→C

import "parser" as ps
import "cgen_c" as cc
import "lexer" as lex
import "checker" as ck
import "std/proc" as proc
import "lsp" as lsp
import "realtime" as rtc


fn last_slash(s: string) -> int {
    let bs = s.bytes()
    var last = 0 - 1
    var i = 0
    loop {
        if i >= bs.len() {
            break
        }
        if int(bs[i]) == 47 {
            last = i
        }
        i = i + 1
    }
    return last
}


fn dirname(s: string) -> string {
    let ls = last_slash(s)
    if ls < 0 {
        return ""
    }
    return byte_slice(s, 0, ls)
}


fn resolve_import(importer: string, imp: string) -> string {
    if imp.len() >= 4 && byte_slice(imp, 0, 4) == "std/" {
        // Resolve the reserved `std/` prefix, mirroring the C frontend's init_std_dir (src/main.c), in order:
        //   1. $INGLE_STD (legacy $EMBER_STD) — an explicit override wins (non-standard layouts).
        //   2. the compiler's OWN binary: <bin>/../std via exe_path() — so an INSTALLED toolchain finds its
        //      stdlib from any working directory, and build/compile_c-self finds the repo std/ too.
        //   3. the plain relative path — a repo checkout run with std/ in the cwd, or an unsupported platform
        //      where exe_path() is "".
        let rest = byte_slice(imp, 4, imp.len())   // the module name after "std/"
        var base = env("INGLE_STD")
        if base == "" {
            base = env("EMBER_STD")
        }
        if base != "" {
            return base + "/" + rest + ".ig"
        }
        let exe = exe_path()
        if exe != "" {
            return dirname(dirname(exe)) + "/std/" + rest + ".ig"   // <exe> -> <bin> -> <prefix>/std
        }
        return imp + ".ig"
    }
    let d = dirname(importer)
    if d == "" {
        return imp + ".ig"
    }
    return d + "/" + imp + ".ig"
}


fn seen_has(seen: [string], p: string) -> bool {
    var i = 0
    loop {
        if i >= seen.len() {
            break
        }
        if seen[i] == p {
            return true
        }
        i = i + 1
    }
    return false
}


// prelude_src is stage-0's PRELUDE_SOURCE (src/main.c), byte-for-byte, so an injected combinator parses
// at the same source lines as stage-0 (the C-emit carries no line info, but the SAME source keeps this
// driver in lockstep with codegen_dump.ig). Only the combinator DECL_FNs are injected; the enums are
// line-positioning (Option/Result stay OUT of the enum table — the C-emit resolves Some/Ok/… by the
// prelude fallback, OFI-204). Braces are `\{`/`\}` — a bare `{` starts string interpolation.
fn prelude_src() -> string {
    return "enum Option<T> \{\n" +
           "    Some(value: T)\n" +
           "    None\n" +
           "\}\n" +
           "enum Result<T, E> \{\n" +
           "    Ok(value: T)\n" +
           "    Err(error: E)\n" +
           "\}\n" +
           "interface Hash \{\n" +
           "    fn hash(self) -> int\n" +
           "\}\n" +
           "interface Eq \{\n" +
           "    fn eq(self, other: Self) -> bool\n" +
           "\}\n" +
           "interface Show \{\n" +
           "    fn show(self) -> string\n" +
           "\}\n" +
           "fn is_some<T>(o: Option<T>) -> bool \{\n" +
           "    match o \{\n" +
           "        case Some(v) \{ return true \}\n" +
           "        case None \{ return false \}\n" +
           "    \}\n" +
           "\}\n" +
           "fn is_none<T>(o: Option<T>) -> bool \{\n" +
           "    match o \{\n" +
           "        case Some(v) \{ return false \}\n" +
           "        case None \{ return true \}\n" +
           "    \}\n" +
           "\}\n" +
           "fn unwrap_or<T: Copy>(o: Option<T>, d: T) -> T \{\n" +
           "    match o \{\n" +
           "        case Some(v) \{ return v \}\n" +
           "        case None \{ return d \}\n" +
           "    \}\n" +
           "\}\n" +
           "fn is_ok<T, E>(r: Result<T, E>) -> bool \{\n" +
           "    match r \{\n" +
           "        case Ok(v) \{ return true \}\n" +
           "        case Err(e) \{ return false \}\n" +
           "    \}\n" +
           "\}\n" +
           "fn is_err<T, E>(r: Result<T, E>) -> bool \{\n" +
           "    match r \{\n" +
           "        case Ok(v) \{ return false \}\n" +
           "        case Err(e) \{ return true \}\n" +
           "    \}\n" +
           "\}\n" +
           "fn ok_or<T, E>(o: Option<T>, e: E) -> Result<T, E> \{\n" +
           "    match o \{\n" +
           "        case Some(v) \{ return Ok(v) \}\n" +
           "        case None \{ return Err(e) \}\n" +
           "    \}\n" +
           "\}\n" +
           "fn map<T, U>(o: Option<T>, f: fn(T) -> U) -> Option<U> \{\n" +
           "    match o \{\n" +
           "        case Some(v) \{ return Some(f(v)) \}\n" +
           "        case None \{ return None \}\n" +
           "    \}\n" +
           "\}\n" +
           "fn and_then<T, U>(o: Option<T>, f: fn(T) -> Option<U>) -> Option<U> \{\n" +
           "    match o \{\n" +
           "        case Some(v) \{ return f(v) \}\n" +
           "        case None \{ return None \}\n" +
           "    \}\n" +
           "\}\n"
}


// collect_idents returns every IDENTIFIER lexeme across the user sources (comments/strings never reach the
// token stream, so a combinator mentioned in a comment is not a false hit) — mirrors stage-0's NameSet.
fn collect_idents(sources: [string]) -> [string] {
    var out: [string] = []
    var si = 0
    loop {
        if si >= sources.len() {
            break
        }
        let toks = lex.lex(sources[si])
        var ti = 0
        loop {
            if ti >= toks.len() {
                break
            }
            // Only a CALL-POSITION identifier (immediately followed by `(` — a free call `f(…)` or a
            // method/UFCS call `x.f(…)`) gates injection, so a combinator NAME used as a variable / struct
            // field (`s.map`) / type is not a false hit. Mirrors stage-0's nameset_collect.
            if ti + 1 < toks.len() {
                match toks[ti].kind {
                    case TIdent {
                        match toks[ti + 1].kind {
                            case TLParen {
                                out.append(toks[ti].text)
                            }
                            case _ {
                            }
                        }
                    }
                    case _ {
                    }
                }
            }
            ti = ti + 1
        }
        si = si + 1
    }
    return out
}


// name_used reports whether `n` appears in the collected identifier set.
fn name_used(names: [string], n: string) -> bool {
    var i = 0
    loop {
        if i >= names.len() {
            break
        }
        if names[i] == n {
            return true
        }
        i = i + 1
    }
    return false
}


// declares_fn reports whether the program already declares a top-level function named `n` — a user's own
// `unwrap_or`/… shadows the prelude combinator (mirrors stage-0's program_declares_fn in src/main.c).
fn declares_fn(decls: [ps.Decl], n: string) -> bool {
    var i = 0
    loop {
        if i >= decls.len() {
            break
        }
        match decls[i] {
            case DFn(f) {
                if f.name == n {
                    return true
                }
            }
            case _ {
            }
        }
        i = i + 1
    }
    return false
}


// Loaded is load_modules' result: the merged decls, each decl's SOURCE-MODULE path (parallel to `decls`), and
// the global import alias->resolved-module-path map (imp_alias[k] -> imp_path[k]). The module info lets the
// C-emit resolve a QUALIFIED call to a free fn whose bare name collides across modules (`json.get` vs
// `http.get`, `ui.new` vs `flare.new`) — pick the same-named fn defined in the aliased module. (OFI-218)
struct Loaded {
    decls: [ps.Decl]
    decl_mods: [string]
    imp_alias: [string]
    imp_path: [string]
}


fn load_modules(entry: string) -> Loaded {
    var seen: [string] = []
    var queue: [string] = []
    var combined: [ps.Decl] = []
    var decl_mods: [string] = []
    var imp_alias: [string] = []
    var imp_path: [string] = []
    var sources: [string] = []
    seen.append(entry)
    queue.append(entry)
    var qi = 0
    loop {
        if qi >= queue.len() {
            break
        }
        let src = read_file(queue[qi])
        let decls = ps.parse(src)
        sources.append(src)
        var di = 0
        loop {
            if di >= decls.len() {
                break
            }
            combined.append(decls[di])
            decl_mods.append(queue[qi])
            di = di + 1
        }
        var ii = 0
        loop {
            if ii >= decls.len() {
                break
            }
            match decls[ii] {
                case DImport(ipath, alias) {
                    let rpath = resolve_import(queue[qi], ipath)
                    imp_alias.append(alias)
                    imp_path.append(rpath)
                    if seen_has(seen, rpath) == false {
                        seen.append(rpath)
                        queue.append(rpath)
                    }
                }
                case _ {
                }
            }
            ii = ii + 1
        }
        qi = qi + 1
    }
    // Inject each prelude combinator the program references (usage-gated, like stage-0's NameSet),
    // appended after all user decls (Option/Result enums discarded — kept out of the enum table, OFI-204).
    let used = collect_idents(sources)
    let pdecls = ps.parse(prelude_src())
    var pi = 0
    loop {
        if pi >= pdecls.len() {
            break
        }
        match pdecls[pi] {
            case DFn(f) {
                if name_used(used, f.name) && declares_fn(combined, f.name) == false {
                    combined.append(pdecls[pi])
                    decl_mods.append("<prelude>")
                }
            }
            case _ {
            }
        }
        pi = pi + 1
    }
    return Loaded { decls: combined, decl_mods: decl_mods, imp_alias: imp_alias, imp_path: imp_path }
}


// entry_import_aliases / entry_import_paths list the ENTRY module's own imports — alias and resolved module
// path, in parallel — for the checker's imported-struct table (OFI-231).
fn entry_import_aliases(decls: [ps.Decl], decl_mods: [string], entry: string) -> [string] {
    var out: [string] = []
    var i = 0
    loop {
        if i >= decls.len() {
            break
        }
        if decl_mods[i] == entry {
            match decls[i] {
                case DImport(ipath, alias) {
                    out.append(alias)
                }
                case _ {
                }
            }
        }
        i = i + 1
    }
    return out
}


fn entry_import_paths(decls: [ps.Decl], decl_mods: [string], entry: string) -> [string] {
    var out: [string] = []
    var i = 0
    loop {
        if i >= decls.len() {
            break
        }
        if decl_mods[i] == entry {
            match decls[i] {
                case DImport(ipath, alias) {
                    out.append(resolve_import(entry, ipath))
                }
                case _ {
                }
            }
        }
        i = i + 1
    }
    return out
}


// dq wraps a path in double quotes for a /bin/sh command line (repo/install paths carry no `"`).
fn dq(s: string) -> string {
    return "\"" + s + "\""
}


// FlavorSpec is the runtime a program's `-o` native link needs: extra -D defines, the runtime static library,
// and extra link libs (raylib/curl/-pthread). The self-hosted compiler is one binary, so it detects the flavor
// from the PROGRAM (its externs + imports + concurrency) at compile time — the runtime analog of the C
// frontend's COMPILE-time `#if` in compile_native (src/main.c). (OFI-224 Stage B5.)
struct FlavorSpec {
    defines: string
    lib: string
    ldextra: string
}


// str_contains reports whether `needle` occurs in `hay` (a tiny substring search — no std/string dependency).
fn str_contains(hay: string, needle: string) -> bool {
    let hb = hay.bytes()
    let nb = needle.bytes()
    if nb.len() == 0 {
        return true
    }
    if nb.len() > hb.len() {
        return false
    }
    var i = 0
    loop {
        if i + nb.len() > hb.len() {
            break
        }
        var j = 0
        var ok = true
        loop {
            if j >= nb.len() {
                break
            }
            if hb[i + j] != nb[j] {
                ok = false
                break
            }
            j = j + 1
        }
        if ok {
            return true
        }
        i = i + 1
    }
    return false
}


// imports_graphics reports whether the merged program pulls in the graphics stack — std/draw or std/ui, directly
// or transitively (a std/flare program imports std/draw), matched on the resolved import paths.
fn imports_graphics(imp_paths: [string]) -> bool {
    var i = 0
    loop {
        if i >= imp_paths.len() {
            break
        }
        if str_contains(imp_paths[i], "draw.ig") || str_contains(imp_paths[i], "ui.ig") {
            return true
        }
        i = i + 1
    }
    return false
}


// flavor_spec picks the runtime + link flags for a program's `-o` native compile, matching the C frontend's
// compile_native precedence (web > graphics > db > concurrent > default). db/web come from the FFI band profile
// (so the linked runtime matches the baked em_ffi indices); graphics from the imports; concurrency from
// program_concurrent. All libs resolve next to THIS binary (bindir). A net-only program keeps the default lib
// (the frontend's net `-o` is likewise curl-less — networking is run via --emit=run, not compiled native).
fn flavor_spec(decls: [ps.Decl], imp_paths: [string], bindir: string) -> FlavorSpec {
    let profile = cc.ffi_band_profile(cc.build_extern_names(decls))
    if profile == 2 {
        return FlavorSpec { defines: "-DEMBER_GRAPHICS=1 -DEMBER_GFX_HEADLESS=1", lib: "{bindir}/libember_rt_web.a", ldextra: "" }
    }
    if imports_graphics(imp_paths) {
        return FlavorSpec { defines: "-DEMBER_PARALLEL=1 -DEMBER_GRAPHICS=1 -DEMBER_NET=1", lib: "{bindir}/libember_rt_net_gfx.a", ldextra: "`pkg-config --libs raylib freetype2` `curl-config --libs` -pthread" }
    }
    if profile == 1 {
        return FlavorSpec { defines: "", lib: "{bindir}/libember_rt_db.a", ldextra: "" }
    }
    if cc.program_concurrent(decls) {
        return FlavorSpec { defines: "-DEMBER_PARALLEL=1", lib: "{bindir}/libember_rt_par.a", ldextra: "-pthread" }
    }
    return FlavorSpec { defines: "", lib: "{bindir}/libember_rt.a", ldextra: "" }
}


// needs_frozen_host reports whether argv asks for something the SELF-HOSTED compiler does not implement — any
// `--` flag other than the two it owns (--emit=run, --emit=c). That covers --lsp, --doctor, the introspection
// --emit modes (ast/tokens/check/bytecode/trace/docs/prove/replay), --run-bytecode, --tape, --freestanding,
// --faults, --version, --help. Those are handed to the frozen stage-0 frontend host. (-o is single-dash, so it
// stays self-handled; a bare `<file.ig>` with no flags emits C, which the -o path's self-invoke relies on.)
fn needs_frozen_host(argv: [string]) -> bool {
    var i = 0
    loop {
        if i >= argv.len() {
            break
        }
        let a = argv[i]
        if a.len() >= 2 && byte_slice(a, 0, 2) == "--" {
            if a != "--emit=run" && a != "--emit=c" && a != "--emit=lib" {
                return true
            }
        }
        i = i + 1
    }
    return false
}


fn main() -> int {
    let argv = args()

    // `--lsp-self`: the in-process self-hosted language server (selfhost/lsp.ig — the v1.1 LSP port, Phase 1:
    // transport + live diagnostics). A DEV flag: the shipping `--lsp` still routes to the frozen stage-0 host
    // below until the port reaches parity, so this can't regress the editor experience. (OFI-224 G6.)
    if argv.len() > 0 && argv[0] == "--lsp-self" {
        return lsp.run()
    }

    // FROZEN-HOST routing: anything the self-hosted compiler doesn't implement (--lsp, --doctor, the
    // introspection --emit modes, --run-bytecode, …) is served by the frozen stage-0 frontend — exec it with
    // the ORIGINAL argv, so the process BECOMES the host (the LSP's long-lived stdio and every exit code flow
    // straight through). Porting these off the frozen frontend (the LSP first) is deferred to v1.1 / G6.
    if needs_frozen_host(argv) {
        let host = "{dirname(exe_path())}/inglec-stage0"
        let _ = exec(host, argv)
        println("inglec: the tooling host is not installed ({host}) — build it with `make stage0`")
        exit(127)
    }

    // Parse `[-o <out>] <file.ig>` — `-o` anywhere selects native-compile mode; the lone non-flag arg is the
    // entry. No `-o` keeps the differential C-emit-to-stdout path (pipe straight to cc).
    var entry = ""
    var outpath = ""
    var emit_mode = ""
    var i = 0
    loop {
        if i >= argv.len() {
            break
        }
        let a = argv[i]
        if a == "-o" && i + 1 < argv.len() {
            outpath = argv[i + 1]
            i = i + 2
        } else if a.len() >= 7 && byte_slice(a, 0, 7) == "--emit=" {
            emit_mode = byte_slice(a, 7, a.len())
            i = i + 1
        } else {
            entry = a
            i = i + 1
        }
    }
    if entry == "" {
        println("usage: inglec [-o <out> | --emit=run | --emit=c | --emit=lib [-o <lib.a>]] <file.ig>")
        exit(1)
    }

    // --emit=run: the self-hosted QUICK-RUN — compile to bytecode (inglec-emberc) then BECOME the standalone
    // bytecode runner (inglec-run) via exec. Frontend-free (no C compiler, no cc) and fast. A single
    // `sh -c 'emberc … && exec runner …'` keeps stdio inherited (so inglec-emberc's check errors and the
    // program's output reach the terminal directly) and propagates exit codes. inglec-emberc does the type
    // check, so this path skips compile_c's own. Both binaries + the stdlib resolve relative to THIS binary
    // (exe_path), so it works installed or in-repo. (OFI-224 Stage B2 dispatcher.)
    if emit_mode == "run" {
        let exe = exe_path()
        let bindir = dirname(exe)
        let stddir = dirname(bindir) + "/std"
        var tmp = env("TMPDIR")
        if tmp == "" {
            tmp = "/tmp"
        }
        let igb = "{tmp}/inglec-run-{to_int(random() * 2000000000.0)}.igb"
        let script = "INGLE_STD=" + dq(stddir) + " " + dq("{bindir}/inglec-emberc") + " " + dq(entry) + " " + dq(igb) + " && exec " + dq("{bindir}/inglec-run") + " " + dq(igb)
        let _ = exec("/bin/sh", ["-c", script])
        println("inglec: could not exec /bin/sh for --emit=run")
        exit(1)
    }

    // 1. TYPE-CHECK the entry program. check_report prints each `file:line: error: msg` and returns the
    //    verdict → REJECT with exit 65 (stage-0's check-error code), so this compiler accepts/rejects the
    //    same programs stage-0 does. The self-hosted checker is single-module + import-lenient. M1 renders
    //    line-granularity positions (statement line); expression precision + column + the LSP port follow.
    let ld = load_modules(entry)
    if ck.check_report_opts(read_file(entry), entry, ck.ext_struct_opts(ld.decls, ld.decl_mods, entry_import_aliases(ld.decls, ld.decl_mods, entry), entry_import_paths(ld.decls, ld.decl_mods, entry), true)) {
        exit(65)
    }
    // 1b. REALTIME-CHECK the merged program (every module): each `realtime fn` must be proven allocation-,
    //     lock- and I/O-free (selfhost/realtime.ig, DSP Phase 1). Same rejection code as a type error.
    if rtc.check_report(ld.decls, ld.decl_mods) {
        exit(65)
    }
    if emit_mode == "lib" {
        // --emit=lib (DSP Phase 1): a STATIC LIBRARY for C to link — no `main`; each `export "c" fn` is a C
        // entry point. Without -o, print the library-mode C (like --emit=c). With -o, compile it and bundle it
        // WITH the runtime into one archive, so a C host links a single `libfoo.a` (plus -lm). Position-
        // independent and symbol-hidden, so it can go into a shared library / plugin bundle that exposes only
        // the exports.
        if outpath == "" {
            cc.emit_library(ld.decls, ld.decl_mods, ld.imp_alias, ld.imp_path, entry)
            exit(0)
        }
        let lexe = exe_path()
        let lbindir = dirname(lexe)
        let linc = dirname(lbindir) + "/include"
        let lfl = flavor_spec(ld.decls, ld.imp_path, lbindir)
        let script = "set -e; T=$(mktemp -d); trap 'rm -rf \"$T\"' EXIT; " + dq(lexe) + " --emit=lib " + dq(entry) + " | cc -std=c17 -O2 -fPIC -fvisibility=hidden -D_DEFAULT_SOURCE " + lfl.defines + " -I" + dq(linc) + " -x c - -c -o \"$T/prog.o\"; rm -f " + dq(outpath) + "; if [ \"$(uname -s)\" = Darwin ]; then libtool -static -o " + dq(outpath) + " \"$T/prog.o\" " + dq(lfl.lib) + " 2>/dev/null; else mkdir \"$T/rt\"; (cd \"$T/rt\" && ar x " + dq(lfl.lib) + "); ar rcs " + dq(outpath) + " \"$T/prog.o\" \"$T\"/rt/*.o; fi"
        let lr = proc.run(script)
        if lr.code() != 0 {
            print(lr.combined())
            println("inglec: library build of {entry} failed")
            exit(1)
        }
        exit(0)
    }
    if outpath == "" {
        // C-EMIT the whole (merged, prelude-injected) program. `exit(0)` sets the success code AND suppresses
        // the runtime's `=> 0` echo, so stdout is exactly the C translation unit — pipe straight to cc.
        cc.emit_program(ld.decls, ld.decl_mods, ld.imp_alias, ld.imp_path, entry)
        exit(0)
    }
    // 2. -o: emit C + cc-link the runtime in ONE step (the frontend's compile_native, relocated into the
    //    self-hosted driver — Stage B1). Re-run SELF in emit mode and pipe into cc reading C from stdin; the
    //    runtime lib + headers are found relative to this binary (exe_path), so it works installed or in-repo.
    let exe = exe_path()
    let bindir = dirname(exe)
    let inc = dirname(bindir) + "/include"
    let fl = flavor_spec(ld.decls, ld.imp_path, bindir)
    // `-x c -` reads the piped C from stdin; `-x none` resets the language so the runtime .a that follows is
    // treated as a library, not compiled as C (its `!<arch>` header would otherwise be a syntax error). The
    // flavor's -D defines + link-extras (raylib/curl/-pthread) match the runtime lib and the emitted em_ffi bands.
    let cmd = dq(exe) + " " + dq(entry) + " | cc -std=c17 -O2 -D_DEFAULT_SOURCE " + fl.defines + " -I" + dq(inc) + " -x c - -x none " + dq(fl.lib) + " " + fl.ldextra + " -lm -o " + dq(outpath)
    let r = proc.run(cmd)
    if r.code() != 0 {
        println("inglec: native compile of {entry} failed")
        exit(1)
    }
    exit(0)
    return 0
}
