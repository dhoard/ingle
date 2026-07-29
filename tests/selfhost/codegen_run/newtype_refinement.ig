// tests/selfhost/codegen_run/newtype_refinement.ig — `type X = base [where pred]` (OFI-149/150) in the
// self-hosted VM backend. A newtype is a DISTINCT nominal type that ERASES to its base at zero runtime cost:
// the constructor `X(v)` is IDENTITY (just the value v — no CALL). A REFINEMENT type adds a `where` predicate
// checked at construction: the predicate is emitted with `self` substituted by the ctor argument, then
// CONTRACT_CHECK'd. The backend had NO DType awareness, so every `X(v)` fell through to the free-call path and
// emitted a bogus `CALL 255 …` → VM segfault. Now a newtype table (name + base kind + `where` predicate exprs)
// is threaded through WitInfo onto the Chunk; the ctor erases + checks. RUN-identity fixture. All values valid,
// so no fault fires. A newtype is nominal, so arithmetic UNWRAPS via `int(x)` first. Runs to 7 + 500 + 80 + 3 = 590.
type UserId = int
type Money = int
type Percent = int where 0 <= self && self <= 100
type NonZero = int where self != 0


fn fee(m: Money) -> Money {
    return m
}


fn main() -> int {
    let u: UserId = UserId(7)            // plain newtype, identity erase
    let m: Money = fee(Money(500))       // newtype through a param + return
    let p: Percent = Percent(80)         // refinement: 0 <= 80 && 80 <= 100 holds
    let z: NonZero = NonZero(3)          // refinement: 3 != 0 holds
    return int(u) + int(m) + int(p) + int(z)   // unwrap each, then sum: 7 + 500 + 80 + 3 = 590
}
