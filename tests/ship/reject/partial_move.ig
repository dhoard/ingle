// OFI-236: moving a uniquely-owned value (an array, a boxed struct) OUT OF A FIELD is a partial move — the
// parent would still own it, so both would free it. Rejected wherever a value is taken: a struct-literal
// field, a `let`, a `return`, an assignment. An inline all-scalar struct field reads out as a copy (fine).
struct Inner {
    x: f32
    y: f32
}

struct Opts {
    names: [string]
    inner: Inner
    label: string
}

struct Holder {
    names: [string]
    n: int

    fn steal(self) -> [string] {
        return self.names
    }
}

fn build(o: Opts) -> Holder {
    let i = o.inner
    let l = o.label
    let ns = o.names
    return Holder { names: o.names, n: 1 }
}

fn main() -> int {
    return 0
}
