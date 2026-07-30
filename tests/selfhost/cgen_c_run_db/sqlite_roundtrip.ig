// tests/selfhost/cgen_c_run_db/sqlite_roundtrip.ig — the self-hosted SQLite FFI band, end-to-end (OFI-224
// v1.0 cutover). A `std/sqlite` program native-compiled by the self-hosted C-emit must link libember_rt_db.a
// and RUN identical to the DB-flavored VM (build/inglec-db). The self-hosted compiler is ONE profile-agnostic
// binary, so it infers the DB band from the program's declared sqlite_* externs (ffi_band_profile) and emits
// em_ffi indices in the db runtime's g_sigs order (default band 0-41, then sqlite_* at 42+) — NOT the http_*
// band the net/default profile uses at 42. Exercises open/exec/prepare/bind/step/column across an in-memory DB
// (deterministic, no file, exits). Runs to the row dump below.
import "std/sqlite" as sql

fn run() -> Result<int, string> {
    let db = sql.open(":memory:")?
    let _ = sql.exec(db, "CREATE TABLE nums(n INTEGER, label TEXT)")?
    let ins = sql.prepare(db, "INSERT INTO nums(n, label) VALUES(?, ?)")?
    let _ = sql.bind_int(ins, 1, 7)
    let _ = sql.bind_text(ins, 2, "seven")
    let _ = sql.step(ins)?
    let sel = sql.prepare(db, "SELECT n, label FROM nums")?
    loop {
        let more = sql.step(sel)?
        if more == false {
            break
        }
        println("n={sql.column_int(sel, 0)} label={sql.column_text(sel, 1)}")
    }
    println("changes={sql.changes(db)}")
    return Ok(0)
}


fn main() -> int {
    match run() {
        case Ok(v) {
            return v
        }
        case Err(e) {
            println("db error: {e}")
            return 1
        }
    }
}
