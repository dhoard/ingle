// lsp.ig — the Ingle language server, in Ingle (the v1.1 / OFI-224 G6 port of src/lsp.c).
//
// PHASE 1: the JSON-RPC transport + live diagnostics. A Content-Length-framed stdio loop (using the
// read_stdin/flush transport natives), the initialize/shutdown/exit handshake, a full-sync document store,
// and didOpen/didChange/didClose → textDocument/publishDiagnostics driven by the self-hosted checker's
// positioned (M1–M3) diagnostics via checker.check_diags. Messages are parsed + built with std/json.
//
// Served IN-PROCESS by the dispatcher (compile_c.ig) behind the `--lsp-self` dev flag; the shipping `--lsp`
// keeps routing to the frozen stage-0 host until this reaches parity (later phases add hover / definition /
// completion / rename / semantic tokens over a SemanticIndex). Editors need no change — same JSON-RPC.

import "std/json" as json
import "std/string" as str
import "checker" as ck
import "parser" as ps
import "lexer" as lx


// A parsed diagnostic: the checker renders each as "doc:line:col: error: msg"; parse_diag splits it back.
struct Diag {
    ok: bool
    line: int
    col: int
    msg: string
}


// The server state: a full-sync document store as parallel uri/text arrays (a doc is one open editor buffer).
struct Server {
    uris: [string]
    texts: [string]


    // find returns the store index of `uri`, or -1.
    fn find(self, uri: string) -> int {
        var i = 0
        loop {
            if i >= self.uris.len() {
                break
            }
            let u = self.uris[i]
            if u == uri {
                return i
            }
            i = i + 1
        }
        return 0 - 1
    }


    // upsert stores (or replaces) the whole text of `uri` (textDocumentSync = Full).
    fn upsert(mut self, uri: string, text: string) {
        let idx = self.find(uri)
        if idx >= 0 {
            self.texts[idx] = text
        } else {
            self.uris.append(uri)
            self.texts.append(text)
        }
    }


    // drop_doc removes `uri` from the store (on didClose).
    fn drop_doc(mut self, uri: string) {
        let idx = self.find(uri)
        if idx >= 0 {
            let _u = self.uris.remove_at(idx)
            let _t = self.texts.remove_at(idx)
        }
    }


    // respond writes a JSON-RPC response `{"jsonrpc":"2.0","id":<id>,"result":<result>}`, echoing the request
    // id verbatim (a number stays a number, a string stays a string).
    fn respond(self, id: json.Json, result: json.Json) {
        let resp = json.obj([json.member("jsonrpc", json.str("2.0")), json.member("id", id), json.member("result", result)])
        write_message(json.stringify(resp))
    }


    // publish type-checks the doc's text and sends a textDocument/publishDiagnostics notification. The checker
    // is single-module + import-lenient (like check_report); it renders each diagnostic as "doc:line:col:
    // error: msg", which parse_diag splits into a 0-based LSP range. (Parse-error reporting is a follow-on —
    // the self-hosted parser best-effort-recovers rather than positioning syntax errors.)
    fn publish(self, uri: string) {
        let idx = self.find(uri)
        if idx < 0 {
            return
        }
        let text = self.texts[idx]
        let raw = ck.check_diags(text, "doc")
        var items: [json.Json] = []
        var i = 0
        loop {
            if i >= raw.len() {
                break
            }
            let line = raw[i]
            let d = parse_diag(line)
            if d.ok {
                items.append(diag_json(d.line, d.col, d.msg))
            }
            i = i + 1
        }
        publish_note(uri, items)
    }


    // symbols_for / completion_for look up the doc's stored text and run the AST/token provider.
    fn symbols_for(self, uri: string) -> json.Json {
        let idx = self.find(uri)
        if idx < 0 {
            var none: [json.Json] = []
            return json.arr(none)
        }
        return document_symbols(self.texts[idx])
    }


    fn completion_for(self, uri: string, ln: int, ch: int) -> json.Json {
        let idx = self.find(uri)
        if idx < 0 {
            var none: [json.Json] = []
            return json.obj([json.member("isIncomplete", json.boolean(false)), json.member("items", json.arr(none))])
        }
        return completion(self.texts[idx], ln, ch)
    }


    fn sighelp_for(self, uri: string, ln: int, ch: int) -> json.Json {
        let idx = self.find(uri)
        if idx < 0 {
            return json.null_value()
        }
        return signature_help(self.texts[idx], ln, ch)
    }


    fn codeaction_for(self, uri: string, sl: int) -> json.Json {
        let idx = self.find(uri)
        if idx < 0 {
            var none: [json.Json] = []
            return json.arr(none)
        }
        return code_actions(self.texts[idx], uri, sl)
    }


    // handle dispatches one decoded message body by its `method`.
    fn handle(mut self, body: string) {
        match json.parse(body) {
            case Ok(msg) {
                let method = json.as_str(json.get(msg, "method"))
                if method == "" {
                    return                                    // a response (no method) — ignore
                }
                let id = json.get(msg, "id")
                let has_id = json.is_null(id) == false
                let params = json.get(msg, "params")
                if method == "initialize" {
                    self.respond(id, capabilities())
                } else if method == "shutdown" {
                    self.respond(id, json.null_value())
                } else if method == "exit" {
                    let _ = flush()
                    exit(0)
                } else if method == "textDocument/didOpen" {
                    let td = json.get(params, "textDocument")
                    let uri = json.as_str(json.get(td, "uri"))
                    let text = json.as_str(json.get(td, "text"))
                    if uri != "" {
                        self.upsert(uri, text)
                        self.publish(uri)
                    }
                } else if method == "textDocument/didChange" {
                    let td = json.get(params, "textDocument")
                    let uri = json.as_str(json.get(td, "uri"))
                    let changes = json.get(params, "contentChanges")
                    let n = json.length(changes)
                    if uri != "" && n > 0 {
                        let last = json.at(changes, n - 1)
                        let text = json.as_str(json.get(last, "text"))
                        self.upsert(uri, text)
                        self.publish(uri)
                    }
                } else if method == "textDocument/didClose" {
                    let td = json.get(params, "textDocument")
                    let uri = json.as_str(json.get(td, "uri"))
                    if uri != "" {
                        self.drop_doc(uri)
                        var empty: [json.Json] = []
                        publish_note(uri, empty)              // clear the editor's squiggles
                    }
                } else if method == "textDocument/documentSymbol" {
                    if has_id {
                        let uri = json.as_str(json.get(json.get(params, "textDocument"), "uri"))
                        self.respond(id, self.symbols_for(uri))
                    }
                } else if method == "textDocument/completion" {
                    if has_id {
                        let uri = json.as_str(json.get(json.get(params, "textDocument"), "uri"))
                        let pos = json.get(params, "position")
                        self.respond(id, self.completion_for(uri, json.as_int(json.get(pos, "line")), json.as_int(json.get(pos, "character"))))
                    }
                } else if method == "textDocument/signatureHelp" {
                    if has_id {
                        let uri = json.as_str(json.get(json.get(params, "textDocument"), "uri"))
                        let pos = json.get(params, "position")
                        self.respond(id, self.sighelp_for(uri, json.as_int(json.get(pos, "line")), json.as_int(json.get(pos, "character"))))
                    }
                } else if method == "textDocument/codeAction" {
                    if has_id {
                        let uri = json.as_str(json.get(json.get(params, "textDocument"), "uri"))
                        let rng = json.get(params, "range")
                        self.respond(id, self.codeaction_for(uri, json.as_int(json.get(json.get(rng, "start"), "line"))))
                    }
                } else {
                    if has_id {
                        self.respond(id, json.null_value())   // unknown request → empty result (client won't hang)
                    }
                }
            }
            case Err(e) {
                return                                        // malformed JSON — drop it
            }
        }
    }
}


// capabilities is the initialize `result`. Phase 1 advertises only what it serves: full document sync +
// diagnostics (published on change). positionEncoding utf-8 → the checker's byte columns pass through as-is.
fn capabilities() -> json.Json {
    let compl = json.obj([json.member("triggerCharacters", json.arr([json.str(".")]))])
    let sighelp = json.obj([json.member("triggerCharacters", json.arr([json.str("("), json.str(",")]))])
    let caps = json.obj([json.member("positionEncoding", json.str("utf-8")), json.member("textDocumentSync", json.num(1)), json.member("documentSymbolProvider", json.boolean(true)), json.member("completionProvider", compl), json.member("signatureHelpProvider", sighelp), json.member("codeActionProvider", json.boolean(true))])
    let info = json.obj([json.member("name", json.str("inglec-lsp")), json.member("version", json.str("0.3.42"))])
    return json.obj([json.member("capabilities", caps), json.member("serverInfo", info)])
}


// diag_json builds one LSP Diagnostic. The checker's line/col are 1-based; LSP positions are 0-based. Phase 1
// uses a minimal one-column range (real token spans are a refinement); severity is always Error, source "inglec".
fn diag_json(line: int, col: int, msg: string) -> json.Json {
    var l = line - 1
    if l < 0 {
        l = 0
    }
    var c = col - 1
    if c < 0 {
        c = 0
    }
    let e = c + 1
    let start = json.obj([json.member("line", json.num(l)), json.member("character", json.num(c))])
    let stop = json.obj([json.member("line", json.num(l)), json.member("character", json.num(e))])
    let range = json.obj([json.member("start", start), json.member("end", stop)])
    return json.obj([json.member("range", range), json.member("severity", json.num(1)), json.member("source", json.str("inglec")), json.member("message", json.str(msg))])
}


// publish_note writes a textDocument/publishDiagnostics notification for `uri` with the given diagnostics.
fn publish_note(uri: string, items: [json.Json]) {
    let params = json.obj([json.member("uri", json.str(uri)), json.member("diagnostics", json.arr(items))])
    let note = json.obj([json.member("jsonrpc", json.str("2.0")), json.member("method", json.str("textDocument/publishDiagnostics")), json.member("params", params)])
    write_message(json.stringify(note))
}


// parse_diag splits a rendered "doc:line:col: error: msg" (or "doc:line: error: msg", or "doc: error: msg")
// back into a structured Diag. The check path is the colon-free sentinel "doc", so splitting the position
// prefix on ':' is unambiguous. A line/decl-level diagnostic with no position lands at line 0, col 0.
fn parse_diag(rawline: string) -> Diag {
    let sep = ": error: "
    let si = str.index_of(rawline, sep)
    if si < 0 {
        return Diag { ok: false, line: 0, col: 0, msg: "" }
    }
    let prefix = str.substring(rawline, 0, si)
    let msg = str.substring(rawline, si + sep.len(), rawline.len())
    let parts = prefix.split(":")
    var line = 0
    var col = 0
    if parts.len() >= 2 {
        let ls = parts[1]
        match ls.parse_int() {
            case Some(n) {
                line = n
            }
            case None {
            }
        }
    }
    if parts.len() >= 3 {
        let cs = parts[2]
        match cs.parse_int() {
            case Some(n) {
                col = n
            }
            case None {
            }
        }
    }
    return Diag { ok: true, line: line, col: col, msg: msg }
}


// ---- Phase 2: AST/token providers (documentSymbol, completion, signatureHelp, codeAction) ------------
//
// These parse (ps.parse) and/or lex (lx.lex) the doc text on demand — both are best-effort on malformed input
// (no crash). Positions come from the AST's FnDecl.line/col (fns + methods) and, for struct/enum/interface/let
// symbols the AST does not carry, from a token scan. lsp.ig cannot `match` the lexer's `Tk` variants across the
// module boundary, so token kinds are compared via lx.kind_name(...) (a stable string like "IDENT" / "LPAREN").

struct Pos {
    line: int
    col: int
    found: bool
}


// keywords is the Ingle keyword set the global completion appends (CompletionItemKind 14), mirroring the C
// server's vocab.def-driven list.
fn keywords() -> [string] {
    return ["fn", "struct", "enum", "interface", "import", "extern", "let", "var", "if", "else", "loop", "for", "in", "match", "case", "return", "break", "continue", "spawn", "nursery", "type", "where", "requires", "ensures", "mut", "move", "as", "implements", "self", "true", "false"]
}


// fn_sig renders "fn name(p: T, …) -> Ret" — completion detail + the signatureHelp label. A self param renders
// bare; an untyped/inferred param renders name-only.
fn fn_sig(f: ps.FnDecl) -> string {
    var s = "fn " + f.name + "("
    var i = 0
    loop {
        if i >= f.params.len() {
            break
        }
        if i > 0 {
            s = s + ", "
        }
        if f.params[i].is_self {
            s = s + "self"
        } else {
            if f.params[i].ty.len() > 0 {
                s = s + f.params[i].name + ": " + ps.ty_str(f.params[i].ty[0])
            } else {
                s = s + f.params[i].name
            }
        }
        i = i + 1
    }
    s = s + ")"
    if f.ret.len() > 0 {
        s = s + " -> " + ps.ty_str(f.ret[0])
    }
    return s
}


// lsp_range builds a 0-based {start:{line,character},end:{line,character}}.
fn lsp_range(sl: int, sc: int, el: int, ec: int) -> json.Json {
    let start = json.obj([json.member("line", json.num(sl)), json.member("character", json.num(sc))])
    let stop = json.obj([json.member("line", json.num(el)), json.member("character", json.num(ec))])
    return json.obj([json.member("start", start), json.member("end", stop)])
}


// tok_before returns the index of the LAST token strictly before the 1-based (line1, col1) cursor, or -1. The
// token stream is position-ordered, so it stops at the first token not-before.
fn tok_before(toks: [lx.Token], line1: int, col1: int) -> int {
    var best = 0 - 1
    var i = 0
    loop {
        if i >= toks.len() {
            break
        }
        let tl = toks[i].line
        let tc = toks[i].col
        if tl < line1 || (tl == line1 && tc < col1) {
            best = i
            i = i + 1
        } else {
            break
        }
    }
    return best
}


// name_pos finds a top-level `<kwname> <name>` declaration (brace-depth 0) in the token stream and returns the
// NAME token's 1-based line/col — the position for a struct/enum/interface/let symbol the AST omits. kwname is
// the leading keyword's lx.kind_name ("STRUCT"/"ENUM"/"INTERFACE"/"LET"/"VAR").
fn name_pos(toks: [lx.Token], kwname: string, name: string) -> Pos {
    var depth = 0
    var i = 0
    loop {
        if i >= toks.len() {
            break
        }
        let kn = lx.kind_name(toks[i].kind)
        if kn == "LBRACE" {
            depth = depth + 1
        }
        if kn == "RBRACE" {
            depth = depth - 1
        }
        if depth == 0 && kn == kwname && i + 1 < toks.len() {
            if lx.kind_name(toks[i + 1].kind) == "IDENT" && toks[i + 1].text == name {
                return Pos { line: toks[i + 1].line, col: toks[i + 1].col, found: true }
            }
        }
        i = i + 1
    }
    return Pos { line: 0, col: 0, found: false }
}


// sym_node builds one hierarchical DocumentSymbol: name + kind + a range/selectionRange spanning the NAME token
// (1-based line/col in → 0-based out), plus a `children` array only when non-empty (matching the C server).
fn sym_node(name: string, kind: int, line1: int, col1: int, kids: [json.Json]) -> json.Json {
    var l = line1 - 1
    if l < 0 {
        l = 0
    }
    var c = col1 - 1
    if c < 0 {
        c = 0
    }
    let e = c + name.len()
    var members = [json.member("name", json.str(name)), json.member("kind", json.num(kind)), json.member("range", lsp_range(l, c, l, e)), json.member("selectionRange", lsp_range(l, c, l, e))]
    if kids.len() > 0 {
        members.append(json.member("children", json.arr(kids)))
    }
    return json.obj(members)
}


// document_symbols returns a hierarchical DocumentSymbol[] over the doc's top-level decls: fn(12), struct(23)
// with field(8)+method(6) children, enum(10) with variant(22) children, interface(11) with method children,
// and top-level let(13). Fields/variants reuse their parent's position (as the C server does).
fn document_symbols(text: string) -> json.Json {
    let decls = ps.parse(text)
    let toks = lx.lex(text)
    var syms: [json.Json] = []
    var i = 0
    loop {
        if i >= decls.len() {
            break
        }
        match decls[i] {
            case DFn(f) {
                var none1: [json.Json] = []
                syms.append(sym_node(f.name, 12, f.line, f.col, none1))
            }
            case DStruct(name, generics, impls, fields, methods, kind) {
                let p = name_pos(toks, "STRUCT", name)
                var kids: [json.Json] = []
                var fi = 0
                loop {
                    if fi >= fields.len() {
                        break
                    }
                    var nf: [json.Json] = []
                    kids.append(sym_node(fields[fi].name, 8, p.line, p.col, nf))
                    fi = fi + 1
                }
                var mi = 0
                loop {
                    if mi >= methods.len() {
                        break
                    }
                    var nm: [json.Json] = []
                    kids.append(sym_node(methods[mi].name, 6, methods[mi].line, methods[mi].col, nm))
                    mi = mi + 1
                }
                syms.append(sym_node(name, 23, p.line, p.col, kids))
            }
            case DEnum(name, generics, impls, variants) {
                let p = name_pos(toks, "ENUM", name)
                var kids: [json.Json] = []
                var vi = 0
                loop {
                    if vi >= variants.len() {
                        break
                    }
                    var nv: [json.Json] = []
                    kids.append(sym_node(variants[vi].name, 22, p.line, p.col, nv))
                    vi = vi + 1
                }
                syms.append(sym_node(name, 10, p.line, p.col, kids))
            }
            case DInterface(name, generics, methods) {
                let p = name_pos(toks, "INTERFACE", name)
                var kids: [json.Json] = []
                var mi = 0
                loop {
                    if mi >= methods.len() {
                        break
                    }
                    var nm: [json.Json] = []
                    kids.append(sym_node(methods[mi].name, 6, methods[mi].line, methods[mi].col, nm))
                    mi = mi + 1
                }
                syms.append(sym_node(name, 11, p.line, p.col, kids))
            }
            case DLet(is_var, name, ty, value) {
                var kw = "LET"
                if is_var {
                    kw = "VAR"
                }
                let p = name_pos(toks, kw, name)
                var none2: [json.Json] = []
                syms.append(sym_node(name, 13, p.line, p.col, none2))
            }
            case _ {
            }
        }
        i = i + 1
    }
    return json.arr(syms)
}


// compl_item / kw_item build CompletionItems. Global completion emits every named top-level decl (kind by
// decl type) with a signature/detail, then the keywords (kind 14). No insertText/snippets (label verbatim).
fn compl_item(label: string, kind: int, detail: string) -> json.Json {
    return json.obj([json.member("label", json.str(label)), json.member("kind", json.num(kind)), json.member("detail", json.str(detail))])
}


fn kw_item(label: string) -> json.Json {
    return json.obj([json.member("label", json.str(label)), json.member("kind", json.num(14))])
}


// member_context reports whether the cursor sits in a `receiver.|` position (the token before it is `.`, or an
// identifier immediately after a `.`). Member completion is a later phase, so global completion defers there.
fn member_context(text: string, line0: int, char0: int) -> bool {
    let toks = lx.lex(text)
    let idx = tok_before(toks, line0 + 1, char0 + 1)
    if idx < 0 {
        return false
    }
    let kn = lx.kind_name(toks[idx].kind)
    if kn == "DOT" {
        return true
    }
    if kn == "IDENT" && idx > 0 && lx.kind_name(toks[idx - 1].kind) == "DOT" {
        return true
    }
    return false
}


// completion returns the global completion list ({isIncomplete:false, items:[…]}) — top-level decls + keywords
// — unless the cursor is in a member position, where it returns empty items (deferred to the SemanticIndex phase).
fn completion(text: string, line0: int, char0: int) -> json.Json {
    var items: [json.Json] = []
    if member_context(text, line0, char0) {
        return json.obj([json.member("isIncomplete", json.boolean(false)), json.member("items", json.arr(items))])
    }
    let decls = ps.parse(text)
    var i = 0
    loop {
        if i >= decls.len() {
            break
        }
        match decls[i] {
            case DFn(f) {
                items.append(compl_item(f.name, 3, fn_sig(f)))
            }
            case DStruct(name, generics, impls, fields, methods, kind) {
                items.append(compl_item(name, 22, "struct " + name))
            }
            case DEnum(name, generics, impls, variants) {
                items.append(compl_item(name, 13, "enum " + name))
            }
            case DInterface(name, generics, methods) {
                items.append(compl_item(name, 8, "interface " + name))
            }
            case DLet(is_var, name, ty, value) {
                items.append(compl_item(name, 6, "let " + name))
            }
            case _ {
            }
        }
        i = i + 1
    }
    let kws = keywords()
    var ki = 0
    loop {
        if ki >= kws.len() {
            break
        }
        items.append(kw_item(kws[ki]))
        ki = ki + 1
    }
    return json.obj([json.member("isIncomplete", json.boolean(false)), json.member("items", json.arr(items))])
}


// sig_help_for builds a SignatureHelp for a free function `f`, highlighting parameter `commas` (clamped to the
// user-passable params — `self` is skipped, matching the C server).
fn sig_help_for(f: ps.FnDecl, commas: int) -> json.Json {
    var params: [json.Json] = []
    var user = 0
    var i = 0
    loop {
        if i >= f.params.len() {
            break
        }
        if f.params[i].is_self == false {
            var plabel = f.params[i].name
            if f.params[i].ty.len() > 0 {
                plabel = plabel + ": " + ps.ty_str(f.params[i].ty[0])
            }
            params.append(json.obj([json.member("label", json.str(plabel))]))
            user = user + 1
        }
        i = i + 1
    }
    var active = commas
    if active < 0 {
        active = 0
    }
    if user > 0 && active > user - 1 {
        active = user - 1
    }
    if user == 0 {
        active = 0
    }
    let sig = json.obj([json.member("label", json.str(fn_sig(f))), json.member("parameters", json.arr(params))])
    return json.obj([json.member("signatures", json.arr([sig])), json.member("activeSignature", json.num(0)), json.member("activeParameter", json.num(active))])
}


// signature_help finds the call the cursor sits inside (walk left from the token before the cursor to the
// enclosing `(` at bracket-depth 0, counting commas for activeParameter), resolves a FREE-function callee by
// name, and returns its SignatureHelp — or null for a member/builtin/unknown callee (member is a later phase).
fn signature_help(text: string, line0: int, char0: int) -> json.Json {
    let toks = lx.lex(text)
    let start = tok_before(toks, line0 + 1, char0 + 1)
    if start < 0 {
        return json.null_value()
    }
    var depth = 0
    var commas = 0
    var open_idx = 0 - 1
    var i = start
    loop {
        if i < 0 {
            break
        }
        let kn = lx.kind_name(toks[i].kind)
        if kn == "RPAREN" || kn == "RBRACKET" || kn == "RBRACE" {
            depth = depth + 1
        } else if kn == "LPAREN" {
            if depth == 0 {
                open_idx = i
                i = 0 - 1
            } else {
                depth = depth - 1
            }
        } else if kn == "LBRACKET" || kn == "LBRACE" {
            if depth == 0 {
                return json.null_value()               // cursor is inside [...] / {...}, not a call
            }
            depth = depth - 1
        } else if kn == "COMMA" {
            if depth == 0 {
                commas = commas + 1
            }
        }
        i = i - 1
    }
    if open_idx <= 0 {
        return json.null_value()
    }
    if lx.kind_name(toks[open_idx - 1].kind) != "IDENT" {
        return json.null_value()
    }
    if open_idx >= 2 && lx.kind_name(toks[open_idx - 2].kind) == "DOT" {
        return json.null_value()                       // a member call — a later phase
    }
    let cname = toks[open_idx - 1].text
    let decls = ps.parse(text)
    var di = 0
    loop {
        if di >= decls.len() {
            break
        }
        match decls[di] {
            case DFn(f) {
                if f.name == cname {
                    return sig_help_for(f, commas)
                }
            }
            case _ {
            }
        }
        di = di + 1
    }
    return json.null_value()
}


// contract_action builds a "refactor.rewrite" CodeAction whose WorkspaceEdit inserts a contract clause on its
// own indented line just before the function body's `{` (a zero-width insertion at the brace, 1-based in).
fn contract_action(uri: string, title: string, clause: string, brace_line1: int, brace_col1: int) -> json.Json {
    var bl = brace_line1 - 1
    if bl < 0 {
        bl = 0
    }
    var bc = brace_col1 - 1
    if bc < 0 {
        bc = 0
    }
    let edit = json.obj([json.member("range", lsp_range(bl, bc, bl, bc)), json.member("newText", json.str("\n    " + clause + "\n"))])
    let changes = json.obj([json.member(uri, json.arr([edit]))])
    let wsedit = json.obj([json.member("changes", changes)])
    return json.obj([json.member("title", json.str(title)), json.member("kind", json.str("refactor.rewrite")), json.member("edit", wsedit)])
}


// code_actions offers the two contract scaffolds when the cursor line is inside a TOP-LEVEL function: it finds
// the enclosing fn (last top-level fn at/before the line), then the body's opening `{`, and emits the edits.
fn code_actions(text: string, uri: string, start_line0: int) -> json.Json {
    var actions: [json.Json] = []
    let cline = start_line0 + 1
    let decls = ps.parse(text)
    var fn_line = 0 - 1
    var fn_col = 0 - 1
    var di = 0
    loop {
        if di >= decls.len() {
            break
        }
        match decls[di] {
            case DFn(f) {
                if f.line > 0 && f.line <= cline && f.line > fn_line {
                    fn_line = f.line
                    fn_col = f.col
                }
            }
            case _ {
            }
        }
        di = di + 1
    }
    if fn_line < 0 {
        return json.arr(actions)
    }
    let toks = lx.lex(text)
    var brace_line = 0 - 1
    var brace_col = 0 - 1
    var i = 0
    loop {
        if i >= toks.len() {
            break
        }
        let tl = toks[i].line
        let tc = toks[i].col
        if lx.kind_name(toks[i].kind) == "LBRACE" && (tl > fn_line || (tl == fn_line && tc >= fn_col)) {
            brace_line = tl
            brace_col = tc
            i = toks.len()
        } else {
            i = i + 1
        }
    }
    if brace_line < 0 {
        return json.arr(actions)
    }
    actions.append(contract_action(uri, "Add a `requires` precondition", "requires true", brace_line, brace_col))
    actions.append(contract_action(uri, "Add an `ensures` postcondition", "ensures result == result", brace_line, brace_col))
    return json.arr(actions)
}


// read_message reads ONE Content-Length-framed message from stdin (headers char-by-char to a blank line, then
// exactly N body bytes), returning the body — or "" at EOF / on a malformed frame. Only Content-Length is read.
fn read_message() -> string {
    var content_length = 0 - 1
    var line = ""
    loop {
        let ch = read_stdin(1)
        if ch.len() == 0 {
            return ""                                          // stream closed
        }
        if ch == "\n" {
            var l = line
            if l.len() > 0 {
                let tail = str.substring(l, l.len() - 1, l.len())
                if tail == "\r" {
                    l = str.substring(l, 0, l.len() - 1)
                }
            }
            if l.len() == 0 {
                break                                          // blank line ends the headers
            }
            if str.starts_with(l, "Content-Length:") {
                let numstr = str.trim(str.substring(l, 15, l.len()))
                match numstr.parse_int() {
                    case Some(n) {
                        content_length = n
                    }
                    case None {
                    }
                }
            }
            line = ""
        } else {
            line = line + ch
        }
    }
    if content_length < 0 {
        return ""
    }
    var body = ""
    var got = 0
    loop {
        if got >= content_length {
            break
        }
        let chunk = read_stdin(content_length - got)
        if chunk.len() == 0 {
            break                                              // EOF mid-body
        }
        body = body + chunk
        got = got + chunk.len()
    }
    return body
}


// write_message frames `body` with a Content-Length header (byte length) + CRLFCRLF, then flushes — an editor
// pipe is fully buffered, so an unflushed reply never arrives.
fn write_message(body: string) {
    print("Content-Length: {body.len()}\r\n\r\n")
    print(body)
    let _ = flush()
}


// run is the server loop: read a framed message, dispatch it, until EOF or an `exit` notification. Exits the
// process directly (no `=> N` return trailer to corrupt the protocol stream).
fn run() -> int {
    var srv = Server { uris: [], texts: [] }
    loop {
        let body = read_message()
        if body.len() == 0 {
            break
        }
        srv.handle(body)
    }
    let _ = flush()
    exit(0)
    return 0
}
