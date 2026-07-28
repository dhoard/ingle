// tests/selfhost/cgen_c/mut_self_value_method.ig — a `mut self` method on a VALUE struct, in the self-hosted
// C-emit (OFI-054, un-dodged). A value struct is passed BY VALUE, so a plain `mut self` copy would lose the
// mutation; stage-0 instead makes such a method a POINTER receiver — `em_s<owner> *a0`, body `(*a0).fN = …`,
// called `em_fn_N(&recv, …)` — so field writes reach the caller's struct. Because the receiver is a raw
// pointer, the method canNOT be reached through em_invoke (the trampoline unboxes a COPY), so it is excluded
// from the dispatch switch but keeps its em_fn index. The self-hosted emit previously passed self by value
// (em_s0 a0) and silently dropped the mutation. Byte-identical to stage-0. Returns a.dot(b) + c.sum() after
// c.scale(10) = 11 + (50+60) = 121.
struct Vec {
    x: int
    y: int

    fn dot(self, o: Vec) -> int {
        return self.x * o.x + self.y * o.y
    }

    fn scale(mut self, k: int) {
        self.x = self.x * k
        self.y = self.y * k
    }

    fn sum(self) -> int {
        return self.x + self.y
    }
}


fn main() -> int {
    let a = Vec { x: 1, y: 2 }
    let b = Vec { x: 3, y: 4 }
    var c = Vec { x: 5, y: 6 }
    c.scale(10)                       // mutates c in place through the pointer receiver
    return a.dot(b) + c.sum()         // 11 + 110 = 121
}
