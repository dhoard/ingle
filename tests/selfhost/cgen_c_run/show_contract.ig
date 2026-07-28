// tests/selfhost/cgen_c_run/show_contract.ig — the OFI-139 structural Show contract in the self-hosted
// C-emit (un-dodged). A value that provides `fn show(self) -> string` is rendered directly by string
// interpolation: `"{value}"` desugars to `"{value.show()}"`. Detection is STRUCTURAL (no `implements Show`
// needed) — a concrete struct with a `.show` method renders via a direct method call; an interface value
// renders via dynamic dispatch on its vtable. The self-hosted checker does not rewrite the AST (stage-0's
// checker does), so emit_str_part synthesises the `.show()` call itself when hole_has_show holds, and routes
// it through emit_call (handling a borrowed / fresh-owned-temp receiver, and an interface receiver). Without
// it, `{point}` passed the raw em_s aggregate to em_to_string (a Value) and failed to compile.
// Run-identical to the VM. Returns p.x + p.y + describe-legs = 3 + 7 + 4 = 14.
struct Point {
    x: int
    y: int

    fn show(self) -> string {
        return "({self.x}, {self.y})"
    }
}


interface Animal {
    fn legs(self) -> int
    fn show(self) -> string
}


struct Cat implements Animal {
    name: string

    fn legs(self) -> int {
        return 4
    }

    fn show(self) -> string {
        return self.name
    }
}


fn describe(a: Animal) -> string {
    return "{a} has {a.legs()} legs"      // {a} dispatches a.show() through the vtable
}


fn main() -> int {
    let p = Point { x: 3, y: 7 }
    println("named={p} temp={Point { x: 1, y: 1 }}")   // borrowed + fresh-owned-temp receivers
    let c = Cat { name: "cat" }
    println(describe(c))
    return p.x + p.y + c.legs()           // 3 + 7 + 4 = 14
}
