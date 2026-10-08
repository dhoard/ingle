// OFI-231: a struct literal of an IMPORTED struct must set every field exactly once and name no unknown field,
// exactly like a local one — a missing field would be left uninitialised.
import "mods/shapes" as sh

fn main() -> int {
    let ok = sh.P { a: 1, b: 2 }
    let missing = sh.P { a: 1 }
    let extra = sh.P { a: 1, b: 2, c: 3 }
    let twice = sh.P { a: 1, a: 2, b: 3 }
    return ok.a + missing.a + extra.a + twice.a
}
