// tests/selfhost/cgen_c_run/try_string_payload.ig — typing the payload of `?` and of a match on a FREE-function
// call that returns Result<T,E>, in the self-hosted C-emit (OFI-173, un-dodged). Two gaps:
//   (1) `let raw = field(t, k)?` where field returns Result<string,_> — `?` yields the STRING payload, so
//       `raw.parse_int()` must resolve. is_string_expr gained an ETry case backed by a per-em_fn ret_ok_str table.
//   (2) `match load_config(t) { case Ok(cfg) { cfg.host } }` — load_config is a FREE-function call returning
//       Result<Config,_>; match_payload_sid gained a free-fn-call case backed by a per-em_fn ret_ok_struct table,
//       so cfg types as a Config and `cfg.host` resolves.
// Run-identical to the VM (the `?` operator lowers to a statement-expression, not stage-0's hoisted form — the
// established cgen_c_run divergence). Returns cfg.port + cfg.host.len() = 8080 + 1 = 8081.
struct Config {
    host: string
    port: int
}


fn field(text: string, key: string) -> Result<string, string> {
    let lines = text.split("\n")
    for line in lines {
        let parts = line.split("=")
        if parts.len() == 2 {
            if parts[0] == key {
                return Ok(parts[1])
            }
        }
    }
    return Err("missing {key}")
}


fn parse_port(text: string) -> Result<int, string> {
    let raw = field(text, "port")?          // (1) raw is a STRING (the Ok payload) — parse_int must resolve
    match raw.parse_int() {
        case Some(n) { return Ok(n) }
        case None    { return Err("nan: {raw}") }
    }
}


fn load_config(text: string) -> Result<Config, string> {
    let h = field(text, "host")?
    let p = parse_port(text)?
    return Ok(Config { host: h, port: p })
}


fn main() -> int {
    match load_config("host=h\nport=8080") {
        case Ok(cfg)  { return cfg.port + cfg.host.len() }   // (2) cfg typed Config → cfg.port / cfg.host resolve; 8080 + 1
        case Err(msg) { println("err {msg}")  return 0 - 1 }  // msg (Err payload) interpolated, as in 03_errors
    }
    return 0 - 99
}
