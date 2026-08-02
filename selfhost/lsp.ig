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
    let caps = json.obj([json.member("positionEncoding", json.str("utf-8")), json.member("textDocumentSync", json.num(1))])
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
