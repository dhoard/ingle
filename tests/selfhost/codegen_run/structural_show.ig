// tests/selfhost/codegen_run/structural_show.ig — OFI-139 structural Show: a value type that provides
// `fn show(self) -> string` is rendered directly by interpolation — `{value}` desugars to `{value.show()}`, with
// no `implements Show` needed (detection is structural). The self-hosted VM backend now synthesises the
// `.show()` call in the interpolation-hole emission (hole_has_show; a concrete struct's `.show` fn OR an
// interface declaring `show`), AND boxes a struct-LITERAL receiver (`{Point{..}}` -> Point{..}.show()) via
// NEW_STRUCT so the method gets a single boxed struct. RUN-identity fixture. Runs to len of "p=(3, 7) o=(0, 0)".
struct Point {
    x: int
    y: int


    fn show(self) -> string {
        return "({self.x}, {self.y})"
    }
}


fn main() -> int {
    let p = Point { x: 3, y: 7 }
    let s = "p={p} o={Point { x: 0, y: 0 }}"   // named-binding receiver AND struct-literal receiver
    return len(s.bytes())                        // "p=(3, 7) o=(0, 0)" -> 17
}
