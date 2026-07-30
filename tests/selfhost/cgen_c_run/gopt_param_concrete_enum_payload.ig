// tests/selfhost/cgen_c_run/gopt_param_concrete_enum_payload.ig — a match on a PARAM whose type is
// Result/Option with a CONCRETE refcounted payload (OFI-224 v1.0 cutover, the json.ig crash class).
// `show(p: Result<Doc, string>)` binds `case Ok(v)` a borrow of an enum the param owns. Consuming v into a
// call (here `render(v)` inside a `{...}` interpolation hole, exactly as json.ig does `json.stringify(v)`)
// must own_into_slot — a retain of the borrowed enum — so the callee's param-drop does not over-free the value
// the scrutinee still owns. The self-hosted emit does not monomorphise, so the concrete refcounted payload was
// missed (only the GENERIC `Option<T>` param was marked): v was passed RAW, the callee freed the shared enum,
// and the NEXT allocation hit a corrupted heap and crashed. The concrete refcounted payload now joins the gopt
// over-approximation (ty_is_refc_concrete), matching stage-0's monomorphised own_into_slot. RUN-identity vs the
// VM; the repeated shows exercise the cross-call corruption. Runs to a=..b=..c(err), exit 0.
enum Doc {
    Text(s: string)
    Num(n: int)
}


fn render(d: Doc) -> string {
    match d {
        case Text(s) {
            return "T:{s}"
        }
        case Num(n) {
            return "N:{n}"
        }
    }
}


fn show(label: string, p: Result<Doc, string>) {
    match p {
        case Ok(v) {
            println("{label}: {render(v)}")     // v (a borrowed refc enum) consumed by render → own_into_slot
        }
        case Err(e) {
            println("{label}: ERR {e}")
        }
    }
}


fn wrap(ok: bool, n: int) -> Result<Doc, string> {
    if ok {
        return Ok(Doc.Num(n))
    }
    return Err("bad")
}


fn main() -> int {
    show("a", wrap(true, 1))       // two owning-enum shows back-to-back — the cross-call corruption case
    show("b", wrap(true, 2))
    show("c", wrap(false, 0))
    return 0
}
