// selfhost/realtime.ig — the `realtime` checker (DSP Phase 1, docs/design/dsp-plugins.md §3.4).
//
// A `realtime fn` is proven never to allocate, free, lock, block, print or do I/O — the audio-thread rule.
// That also makes it thread-safe against the runtime: realtime code never touches the (single, unlocked)
// heap context, so an audio thread and a UI thread cannot race on it.
//
// The check is an ALLOW-LIST over the MERGED program (every module, so an imported library's realtime fns
// are checked too, and a call into one is known to be realtime). A realtime body may use only:
//   - numeric / bool / Ptr locals and literals, and arithmetic, compares and logic on them;
//   - reads of parameters and struct fields of any type, `x.len()`, and indexing an array of NUMBERS;
//   - assignment to a number local, a number field, or an element of a number array;
//   - if / loop / break / continue / return / match, and `for` over a range or a number array;
//   - calls to `realtime` fns, `realtime` methods, `extern "c" { realtime fn … }`, numeric conversions,
//     and the allocation-free builtins (abs, floor, ceil, round, sqrt, pow, min, max, to_int, to_float,
//     float_bits, wrapping_*, len, assert, panic).
// Anything else — a string, an array/struct/enum value being built, a closure, `?`, spawn/nursery/channels,
// print, a call to a non-realtime fn — is rejected with the construct named. Because it is an allow-list, a
// NEW language feature is rejected in realtime code until it is deliberately admitted here.
//
// Types are resolved from declarations (param/field/return annotations), not the lenient checker — so
// anything the pass cannot prove is a number is rejected too ("cannot prove …").

import "parser" as ps


let K_UNKNOWN: int = 0
let K_NUM: int = 1
let K_BOOL: int = 2
let K_ARR_NUM: int = 3     // an array (or slice) of numbers/bools — indexing it reads a packed scalar
let K_ARR_OTHER: int = 4   // an array of anything else — indexing it copies a boxed element
let K_STRUCT: int = 5      // a user struct (RtTy.s = its name)
let K_PTR: int = 6
let K_HEAP: int = 7        // a string, enum, closure, map … — a heap value
let K_UNIT: int = 8


struct RtTy {
    k: int
    s: string
}


fn rt(k: int) -> RtTy {
    return RtTy { k: k, s: "" }
}


fn is_scalar_k(k: int) -> bool {
    return k == K_NUM || k == K_BOOL || k == K_PTR
}


fn is_num_typename(n: string) -> bool {
    return n == "int" || n == "float" || n == "i8" || n == "i16" || n == "i32" || n == "i64" || n == "u8" || n == "u16" || n == "u32" || n == "u64" || n == "f32" || n == "f64"
}


// allocation-free builtins callable from realtime code (numeric conversions are handled separately).
fn rt_builtin(n: string) -> bool {
    return n == "abs" || n == "floor" || n == "ceil" || n == "round" || n == "sqrt" || n == "pow" || n == "min" || n == "max" || n == "to_int" || n == "to_float" || n == "float_bits" || n == "wrapping_add" || n == "wrapping_sub" || n == "wrapping_mul" || n == "len" || n == "assert" || n == "panic"
}


fn has(xs: [string], v: string) -> bool {
    var i = 0
    loop {
        if i >= xs.len() {
            break
        }
        if xs[i] == v {
            return true
        }
        i = i + 1
    }
    return false
}


fn idx(xs: [string], v: string) -> int {
    var i = 0
    loop {
        if i >= xs.len() {
            break
        }
        if xs[i] == v {
            return i
        }
        i = i + 1
    }
    return 0 - 1
}


fn is_plain_str(e: ps.Expr) -> bool {
    match e {
        case EStr(parts) {
            var i = 0
            loop {
                if i >= parts.len() {
                    break
                }
                if parts[i].hole.len() > 0 {
                    return false
                }
                i = i + 1
            }
            return true
        }
        case _ {
            return false
        }
    }
}


struct Rt {
    // program tables (merged, keyed by bare name — module qualifiers are dropped)
    s_names: [string]
    v_names: [string]          // enum variant names (constructing one allocates)
    nt_names: [string]         // newtypes …
    nt_k: [int]                // … and their base class
    aliases: [string]          // import aliases (`dsp.f(…)` is a qualified free-fn call)
    g_names: [string]          // module-level constants …
    g_k: [int]
    fn_names: [string]
    fn_rt: [bool]
    fn_retk: [int]
    fn_rets: [string]
    m_owner: [string]
    m_names: [string]
    m_rt: [bool]
    m_retk: [int]
    m_rets: [string]
    f_owner: [string]
    f_names: [string]
    f_k: [int]
    f_s: [string]
    scalar_structs: [string]   // structs whose every field is a number/bool or (recursively) such a struct — a
                               // VALUE type held on the stack by native code, so building/copying one is free
    // per-function state
    env_names: [string]
    env_k: [int]
    env_s: [string]
    file: string
    fname: string
    line: int
    col: int
    diags: [string]


    fn ty_class(self, t: ps.Ty) -> RtTy {
        match t {
            case TyName(q, n) {
                if is_num_typename(n) {
                    return rt(K_NUM)
                }
                if n == "bool" {
                    return rt(K_BOOL)
                }
                if n == "Ptr" {
                    return rt(K_PTR)
                }
                if has(self.s_names, n) {
                    return RtTy { k: K_STRUCT, s: n }
                }
                let ni = idx(self.nt_names, n)
                if ni >= 0 {
                    return rt(self.nt_k[ni])
                }
                return rt(K_HEAP)
            }
            case TyArray(elem) {
                let ek = self.ty_class(elem.value).k
                if ek == K_NUM || ek == K_BOOL {
                    return rt(K_ARR_NUM)
                }
                return rt(K_ARR_OTHER)
            }
            case TyGeneric(q, n, args) {
                if n == "Slice" && args.len() == 1 {
                    let sk = self.ty_class(args[0]).k
                    if sk == K_NUM || sk == K_BOOL {
                        return rt(K_ARR_NUM)
                    }
                    return rt(K_ARR_OTHER)
                }
                return rt(K_HEAP)
            }
            case _ {
                return rt(K_HEAP)
            }
        }
    }


    fn ret_class(self, f: ps.FnDecl) -> RtTy {
        if f.ret.len() == 0 {
            return rt(K_UNIT)
        }
        return self.ty_class(f.ret[0])
    }


    fn build(mut self, decls: [ps.Decl]) {
        var i = 0
        loop {                                    // pass 1: type names (struct/enum/newtype classes need them)
            if i >= decls.len() {
                break
            }
            match decls[i] {
                case DStruct(name, generics, impls, fields, methods, kind) {
                    self.s_names.append(name)
                }
                case DEnum(name, generics, impls, variants) {
                    var v = 0
                    loop {
                        if v >= variants.len() {
                            break
                        }
                        self.v_names.append(variants[v].name)
                        v = v + 1
                    }
                }
                case DImport(path, alias) {
                    self.aliases.append(alias)
                }
                case _ {
                }
            }
            i = i + 1
        }
        self.v_names.append("Some")
        self.v_names.append("None")
        self.v_names.append("Ok")
        self.v_names.append("Err")
        i = 0
        loop {                                    // pass 2: signatures, fields, newtypes, constants
            if i >= decls.len() {
                break
            }
            match decls[i] {
                case DType(name, base, pred) {
                    self.nt_names.append(name)
                    self.nt_k.append(self.ty_class(base.value).k)
                }
                case DFn(f) {
                    self.add_fn(f)
                }
                case DExtern(abi, fns) {
                    var e = 0
                    loop {
                        if e >= fns.len() {
                            break
                        }
                        self.add_fn(fns[e])
                        e = e + 1
                    }
                }
                case DStruct(name, generics, impls, fields, methods, kind) {
                    var fi = 0
                    loop {
                        if fi >= fields.len() {
                            break
                        }
                        let fc = self.ty_class(fields[fi].ty)
                        self.f_owner.append(name)
                        self.f_names.append(fields[fi].name)
                        self.f_k.append(fc.k)
                        self.f_s.append(fc.s)
                        fi = fi + 1
                    }
                    var mi = 0
                    loop {
                        if mi >= methods.len() {
                            break
                        }
                        let rc = self.ret_class(methods[mi])
                        self.m_owner.append(name)
                        self.m_names.append(methods[mi].name)
                        self.m_rt.append(methods[mi].is_realtime)
                        self.m_retk.append(rc.k)
                        self.m_rets.append(rc.s)
                        mi = mi + 1
                    }
                }
                case DLet(is_var, name, ty, value) {
                    var gk = K_UNKNOWN
                    if ty.len() > 0 {
                        gk = self.ty_class(ty[0]).k
                    } else {
                        match value.value {
                            case EInt(v, kd) {
                                gk = K_NUM
                            }
                            case EFloat(v) {
                                gk = K_NUM
                            }
                            case EBool(v) {
                                gk = K_BOOL
                            }
                            case _ {
                            }
                        }
                    }
                    self.g_names.append(name)
                    self.g_k.append(gk)
                }
                case _ {
                }
            }
            i = i + 1
        }
    }


    // mark_scalar_structs finds every all-scalar struct (to a fixed point, so nesting resolves in any order).
    fn mark_scalar_structs(mut self) {
        loop {
            var grew = false
            var si = 0
            loop {
                if si >= self.s_names.len() {
                    break
                }
                let sn = self.s_names[si]
                if has(self.scalar_structs, sn) == false {
                    var ok = true
                    var fi = 0
                    loop {
                        if fi >= self.f_owner.len() {
                            break
                        }
                        if self.f_owner[fi] == sn {
                            let fk = self.f_k[fi]
                            let nested = fk == K_STRUCT && has(self.scalar_structs, self.f_s[fi])
                            if fk != K_NUM && fk != K_BOOL && nested == false {
                                ok = false
                            }
                        }
                        fi = fi + 1
                    }
                    if ok {
                        self.scalar_structs.append(sn)
                        grew = true
                    }
                }
                si = si + 1
            }
            if grew == false {
                break
            }
        }
    }


    // value_ok: a value realtime code may bind, assign, build or return — a number/bool/Ptr, or an all-scalar
    // struct (a stack value in native code).
    fn value_ok(self, t: RtTy) -> bool {
        return is_scalar_k(t.k) || (t.k == K_STRUCT && has(self.scalar_structs, t.s))
    }


    fn add_fn(mut self, f: ps.FnDecl) {
        let rc = self.ret_class(f)
        self.fn_names.append(f.name)
        self.fn_rt.append(f.is_realtime)
        self.fn_retk.append(rc.k)
        self.fn_rets.append(rc.s)
    }


    fn err(mut self, what: string) {
        self.diags.append("{self.file}:{self.line}:{self.col}: error: realtime fn '{self.fname}' {what}")
    }


    fn at(mut self, line: int, col: int) {
        if line > 0 {
            self.line = line
            self.col = col
        }
    }


    fn declare(mut self, name: string, t: RtTy) {
        self.env_names.append(name)
        self.env_k.append(t.k)
        self.env_s.append(t.s)
    }


    fn lookup(self, name: string) -> int {
        var i = self.env_names.len() - 1
        loop {
            if i < 0 {
                break
            }
            if self.env_names[i] == name {
                return i
            }
            i = i - 1
        }
        return 0 - 1
    }


    fn field(self, owner: string, name: string) -> RtTy {
        var i = 0
        loop {
            if i >= self.f_owner.len() {
                break
            }
            if self.f_owner[i] == owner && self.f_names[i] == name {
                return RtTy { k: self.f_k[i], s: self.f_s[i] }
            }
            i = i + 1
        }
        return rt(K_UNKNOWN)
    }


    fn method(self, owner: string, name: string) -> int {
        var i = 0
        loop {
            if i >= self.m_owner.len() {
                break
            }
            if self.m_owner[i] == owner && self.m_names[i] == name {
                return i
            }
            i = i + 1
        }
        return 0 - 1
    }


    // check_fn checks one realtime fn (or method, with `owner` its struct): the signature, then the body.
    fn check_fn(mut self, f: ps.FnDecl, owner: string, file: string) {
        var fresh: [string] = []
        var freshk: [int] = []
        var freshs: [string] = []
        self.env_names = fresh
        self.env_k = freshk
        self.env_s = freshs
        self.file = file
        self.fname = f.name
        if owner != "" {
            self.fname = "{owner}.{f.name}"
        }
        self.line = f.line
        self.col = f.col
        var p = 0
        loop {
            if p >= f.params.len() {
                break
            }
            if f.params[p].is_self {
                self.declare("self", RtTy { k: K_STRUCT, s: owner })
            } else {
                var pc = rt(K_UNKNOWN)
                if f.params[p].ty.len() > 0 {
                    pc = self.ty_class(f.params[p].ty[0])
                }
                if f.params[p].qual == 2 && self.value_ok(pc) == false {
                    self.err("takes '{f.params[p].name}' by 'move' — it would be freed at the end of the call")
                }
                self.declare(f.params[p].name, pc)
            }
            p = p + 1
        }
        let rc = self.ret_class(f)
        if self.value_ok(rc) == false && rc.k != K_UNIT {
            self.err("returns a value that is not a number, bool, Ptr or all-number struct — building it would allocate")
        }
        self.block(f.body)
    }


    fn block(mut self, body: [ps.Stmt]) {
        var i = 0
        loop {
            if i >= body.len() {
                break
            }
            self.stmt(body[i])
            i = i + 1
        }
    }


    fn stmt(mut self, s: ps.Stmt) {
        match s {
            case SLet(is_var, name, ty, value, nline, ncol) {
                self.at(value.line, value.col)
                let vt = self.expr(value.value)
                var t = vt
                if ty.len() > 0 {
                    t = self.ty_class(ty[0])
                }
                if self.value_ok(t) == false {
                    self.err("binds '{name}' to a value that is not a number, bool, Ptr or all-number struct — copying it may allocate (read or index it in place instead)")
                }
                self.declare(name, t)
            }
            case SReturn(value, line) {
                if value.len() > 0 {
                    self.at(value[0].line, value[0].col)
                    let _ = self.expr(value[0].value)
                }
            }
            case SExpr(expr) {
                self.at(expr.line, expr.col)
                let _ = self.expr(expr.value)
            }
            case SAssign(target, value) {
                self.at(target.line, target.col)
                let tt = self.target(target.value)
                let _ = self.expr(value.value)
                if self.value_ok(tt) == false {
                    self.err("assigns to something that is not a number, bool, Ptr or all-number struct — the old value would be freed")
                }
            }
            case SIf(cond, then_blk, els) {
                self.at(cond.line, cond.col)
                let _ = self.expr(cond.value)
                self.block(then_blk)
                self.block(els)
            }
            case SFor(vname, index_var, iter, body, nline, ncol) {
                self.at(iter.line, iter.col)
                match iter.value {
                    case ERange(lo, hi) {
                        let _ = self.expr(lo.value)
                        let _ = self.expr(hi.value)
                        self.declare(vname, rt(K_NUM))
                    }
                    case _ {
                        let it = self.expr(iter.value)
                        if it.k != K_ARR_NUM {
                            self.err("loops over something that is not a range or an array of numbers")
                        }
                        self.declare(vname, rt(K_NUM))
                    }
                }
                if index_var != "" {
                    self.declare(index_var, rt(K_NUM))
                }
                self.block(body)
            }
            case SLoop(body) {
                self.block(body)
            }
            case SMatch(value, cases) {
                self.at(value.line, value.col)
                let _ = self.expr(value.value)
                var c = 0
                loop {
                    if c >= cases.len() {
                        break
                    }
                    var b = 0
                    loop {
                        if b >= cases[c].pattern.bindings.len() {
                            break
                        }
                        self.declare(cases[c].pattern.bindings[b], rt(K_UNKNOWN))
                        b = b + 1
                    }
                    if cases[c].guard.len() > 0 {
                        let _ = self.expr(cases[c].guard[0])
                    }
                    self.block(cases[c].body)
                    c = c + 1
                }
            }
            case SSpawn(call) {
                self.at(call.line, call.col)
                self.err("spawns a task — that allocates and synchronises")
            }
            case SNursery(body, line) {
                self.at(line, 0)
                self.err("opens a nursery — that allocates and blocks")
            }
            case SBlock(body) {
                self.block(body)
            }
            case _ {
            }
        }
    }


    // target classifies an assignment target (a local, a field, or an indexed element).
    fn target(mut self, e: ps.Expr) -> RtTy {
        match e {
            case EIndex(object, index) {
                let _ = self.expr(index.value)
                let ot = self.expr(object.value)
                if ot.k == K_ARR_NUM {
                    return rt(K_NUM)
                }
                return rt(K_UNKNOWN)
            }
            case _ {
                return self.expr(e)
            }
        }
    }


    fn expr(mut self, e: ps.Expr) -> RtTy {
        match e {
            case EInt(v, kd) {
                return rt(K_NUM)
            }
            case EFloat(v) {
                return rt(K_NUM)
            }
            case EBool(v) {
                return rt(K_BOOL)
            }
            case EStr(parts) {
                self.err("builds a string — that allocates")
                return rt(K_HEAP)
            }
            case EIdent(name) {
                let li = self.lookup(name)
                if li >= 0 {
                    return RtTy { k: self.env_k[li], s: self.env_s[li] }
                }
                let gi = idx(self.g_names, name)
                if gi >= 0 {
                    return rt(self.g_k[gi])
                }
                if has(self.v_names, name) {
                    self.err("uses the enum value '{name}'")
                    return rt(K_HEAP)
                }
                if has(self.fn_names, name) {
                    self.err("uses the function '{name}' as a value — that creates a closure")
                    return rt(K_HEAP)
                }
                return rt(K_UNKNOWN)
            }
            case EUnary(op, operand) {
                let ot = self.expr(operand.value)
                if ps.unop_id(op) == 2 {
                    return rt(K_BOOL)
                }
                if ot.k != K_NUM {
                    self.err("negates something it cannot prove is a number")
                }
                return rt(K_NUM)
            }
            case EBinary(op, l, r) {
                let lt = self.expr(l.value)
                let rtt = self.expr(r.value)
                let bid = ps.binop_id(op)
                if bid == 12 || bid == 13 {
                    return rt(K_BOOL)
                }
                if bid >= 6 && bid <= 11 {
                    if is_scalar_k(lt.k) == false || is_scalar_k(rtt.k) == false {
                        self.err("compares values it cannot prove are numbers, bools or Ptrs")
                    }
                    return rt(K_BOOL)
                }
                if lt.k != K_NUM || rtt.k != K_NUM {
                    self.err("does arithmetic on values it cannot prove are numbers (a string `+` allocates)")
                }
                return rt(K_NUM)
            }
            case ECall(callee, args, names) {
                return self.call(callee.value, args)
            }
            case EGet(object, name) {
                match object.value {
                    case EIdent(oname) {
                        if self.lookup(oname) < 0 && has(self.aliases, oname) {
                            let gi = idx(self.g_names, name)   // a module constant `dsp.TAU`
                            if gi >= 0 {
                                return rt(self.g_k[gi])
                            }
                            return rt(K_UNKNOWN)
                        }
                    }
                    case _ {
                    }
                }
                let ot = self.expr(object.value)
                if ot.k == K_STRUCT {
                    return self.field(ot.s, name)
                }
                return rt(K_UNKNOWN)
            }
            case EIndex(object, index) {
                match index.value {
                    case ERange(lo, hi) {
                        self.err("slices an array — that allocates a view")
                        return rt(K_HEAP)
                    }
                    case _ {
                    }
                }
                let it = self.expr(index.value)
                if it.k != K_NUM {
                    self.err("indexes with something it cannot prove is a number")
                }
                let ot = self.expr(object.value)
                if ot.k == K_ARR_NUM {
                    return rt(K_NUM)
                }
                if ot.k == K_ARR_OTHER {
                    self.err("indexes an array whose elements are not numbers — reading one copies it")
                } else {
                    self.err("indexes something it cannot prove is an array of numbers")
                }
                return rt(K_UNKNOWN)
            }
            case EArray(elems, lines) {
                self.err("builds an array — that allocates")
                return rt(K_HEAP)
            }
            case EStructLit(ty, fields) {
                // an ALL-SCALAR struct is a value on the native stack — building one is free; its field values
                // must themselves be realtime-clean. Any other struct is a heap object.
                var fv = 0
                loop {
                    if fv >= fields.len() {
                        break
                    }
                    let _ = self.expr(fields[fv].value)
                    fv = fv + 1
                }
                let st = self.ty_class(ty.value)
                if st.k == K_STRUCT && has(self.scalar_structs, st.s) {
                    return st
                }
                self.err("builds a struct value that is not all numbers — that allocates")
                return rt(K_HEAP)
            }
            case ETry(operand) {
                self.err("uses `?` — propagating an error builds an enum value")
                return rt(K_HEAP)
            }
            case ERange(lo, hi) {
                self.err("builds a range value")
                return rt(K_HEAP)
            }
            case ELambda(params, body) {
                self.err("creates a closure — that allocates")
                return rt(K_HEAP)
            }
            case _ {
                return rt(K_UNKNOWN)
            }
        }
    }


    fn call(mut self, callee: ps.Expr, args: [ps.Expr]) -> RtTy {
        var a = 0
        loop {
            if a >= args.len() {
                break
            }
            if is_plain_str(args[a]) == false {   // an interned literal message (assert/panic) is not built
                let _ = self.expr(args[a])
            }
            a = a + 1
        }
        match callee {
            case EIdent(name) {
                if self.lookup(name) >= 0 {
                    self.err("calls the closure '{name}' — realtime code calls named realtime fns only")
                    return rt(K_UNKNOWN)
                }
                let fi = idx(self.fn_names, name)
                if fi >= 0 {
                    if self.fn_rt[fi] == false {
                        self.err("calls '{name}', which is not `realtime`")
                    }
                    return RtTy { k: self.fn_retk[fi], s: self.fn_rets[fi] }
                }
                if is_num_typename(name) || name == "bool" {
                    if name == "bool" {
                        return rt(K_BOOL)
                    }
                    return rt(K_NUM)
                }
                let ni = idx(self.nt_names, name)
                if ni >= 0 {
                    if is_scalar_k(self.nt_k[ni]) == false {
                        self.err("constructs the newtype '{name}' over a heap value")
                    }
                    return rt(self.nt_k[ni])
                }
                if rt_builtin(name) {
                    if name == "assert" || name == "panic" {
                        return rt(K_UNIT)
                    }
                    return rt(K_NUM)
                }
                if has(self.v_names, name) {
                    self.err("constructs the enum value '{name}(…)' — that allocates")
                    return rt(K_HEAP)
                }
                self.err("calls '{name}', which is not `realtime`")
                return rt(K_UNKNOWN)
            }
            case EGet(object, mname) {
                match object.value {
                    case EIdent(oname) {
                        if self.lookup(oname) < 0 && has(self.aliases, oname) {
                            // a module-qualified free fn `dsp.process(…)`
                            let qi = idx(self.fn_names, mname)
                            if qi >= 0 {
                                if self.fn_rt[qi] == false {
                                    self.err("calls '{oname}.{mname}', which is not `realtime`")
                                }
                                return RtTy { k: self.fn_retk[qi], s: self.fn_rets[qi] }
                            }
                            self.err("calls '{oname}.{mname}', which is not `realtime`")
                            return rt(K_UNKNOWN)
                        }
                    }
                    case _ {
                    }
                }
                let ot = self.expr(object.value)
                if mname == "len" && (ot.k == K_ARR_NUM || ot.k == K_ARR_OTHER) {
                    return rt(K_NUM)
                }
                if ot.k == K_STRUCT {
                    let mi = self.method(ot.s, mname)
                    if mi >= 0 {
                        if self.m_rt[mi] == false {
                            self.err("calls '{ot.s}.{mname}', which is not `realtime`")
                        }
                        return RtTy { k: self.m_retk[mi], s: self.m_rets[mi] }
                    }
                }
                self.err("calls the method '{mname}', which it cannot prove is `realtime`")
                return rt(K_UNKNOWN)
            }
            case _ {
                self.err("calls a computed function value")
                return rt(K_UNKNOWN)
            }
        }
    }
}


// check_report checks every `realtime` fn and method in the merged program, PRINTS each diagnostic
// (`file:line:col: error: realtime fn 'name' …`), and returns true when any was found. It prints from the
// diags FIELD rather than returning the list (a [string] indexed across a module return can mis-render —
// the OFI-173 class).
fn check_report(decls: [ps.Decl], decl_mods: [string]) -> bool {
    var es: [string] = []
    var ek1: [int] = []
    var ek2: [int] = []
    var ek3: [int] = []
    var ek4: [int] = []
    var ek5: [int] = []
    var ek6: [int] = []
    var eb1: [bool] = []
    var eb2: [bool] = []
    var r = Rt { s_names: es, v_names: [], nt_names: [], nt_k: ek1, aliases: [], g_names: [], g_k: ek2, fn_names: [], fn_rt: eb1, fn_retk: ek3, fn_rets: [], m_owner: [], m_names: [], m_rt: eb2, m_retk: ek4, m_rets: [], f_owner: [], f_names: [], f_k: ek5, f_s: [], scalar_structs: [], env_names: [], env_k: ek6, env_s: [], file: "", fname: "", line: 0, col: 0, diags: [] }
    r.build(decls)
    r.mark_scalar_structs()
    var i = 0
    loop {
        if i >= decls.len() {
            break
        }
        match decls[i] {
            case DFn(f) {
                if f.is_realtime && f.has_body {
                    r.check_fn(f, "", decl_mods[i])
                }
            }
            case DStruct(name, generics, impls, fields, methods, kind) {
                var m = 0
                loop {
                    if m >= methods.len() {
                        break
                    }
                    if methods[m].is_realtime && methods[m].has_body {
                        r.check_fn(methods[m], name, decl_mods[i])
                    }
                    m = m + 1
                }
            }
            case _ {
            }
        }
        i = i + 1
    }
    var d = 0
    loop {
        if d >= r.diags.len() {
            break
        }
        println(r.diags[d])
        d = d + 1
    }
    return r.diags.len() > 0
}
