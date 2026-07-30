// tests/selfhost/cgen_c_run_web/web_set_html.ig — the self-hosted WEB FFI band, end-to-end (OFI-224 v1.0
// cutover). A `std/web` program native-compiled by the self-hosted C-emit must link the headless web runtime
// (build/libember_rt_web.a) and RUN identical to the WEB-flavored VM (build/inglec-web). Importing std/web
// DECLARES the web_* externs, so ffi_band_profile picks the WEB band and the emitted em_ffi indices land in the
// web runtime's g_sigs order — the web_* band at 42-46 (where the net profile puts http_*), NOT a collision.
// web_set_html is non-blocking (returns i64) so this renders one page and exits, deterministically. Runs to the
// line below.
import "std/web" as web

fn main() -> int {
    web.set_html("<h1>hello from the web band</h1>")   // -> web_set_html (band index 42), headless stub
    println("html set ok")
    return 0
}
