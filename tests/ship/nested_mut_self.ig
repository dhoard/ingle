// OFI-233: a `mut self` method called on a struct that lives INSIDE another struct (an inline field, or an
// element of a struct array) must update that inner struct in place — not a temporary copy that is thrown away.
// Covers: a field of an all-scalar (value) parent, fields + array elements of a BOXED parent, a local array.

struct Acc {
    n: i64
    sum: f64

    fn add(mut self, x: f64) -> f64 {
        self.n = self.n + 1
        self.sum = self.sum + x
        return self.sum
    }
}

// an ALL-SCALAR outer struct (itself a value type) holding an inline Acc
struct Pair {
    a: Acc
    b: Acc

    fn feed(mut self, x: f64) {
        let _ = self.a.add(x)
        let _ = self.b.add(x * 2.0)
    }
}

// a BOXED outer struct (it has an array) holding inline Accs and an array of Accs
struct Bank {
    one: Acc
    many: [Acc]
    tag: string

    fn feed(mut self, x: f64) {
        let _ = self.one.add(x)
        for i in 0..self.many.len() {
            let _ = self.many[i].add(x * to_float(i + 1))
        }
    }
}

fn main() -> int {
    var p = Pair { a: Acc { n: 0, sum: 0.0 }, b: Acc { n: 0, sum: 0.0 } }
    p.feed(1.5)
    p.feed(2.5)
    println("pair a={p.a.n}/{p.a.sum} b={p.b.n}/{p.b.sum}")

    var bank = Bank { one: Acc { n: 0, sum: 0.0 }, many: [Acc { n: 0, sum: 0.0 }, Acc { n: 0, sum: 0.0 }], tag: "t" }
    bank.feed(1.0)
    bank.feed(10.0)
    println("bank one={bank.one.n}/{bank.one.sum} m0={bank.many[0].n}/{bank.many[0].sum} m1={bank.many[1].n}/{bank.many[1].sum}")

    var accs = [Acc { n: 0, sum: 0.0 }, Acc { n: 0, sum: 0.0 }]
    let r = accs[1].add(4.0)
    let r2 = accs[1].add(1.0)
    println("local array: r={r} r2={r2} a1={accs[1].n}/{accs[1].sum} a0={accs[0].n}")
    return 0
}
