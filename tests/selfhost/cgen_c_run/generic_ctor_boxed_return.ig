// tests/selfhost/cgen_c_run/generic_ctor_boxed_return.ig — a generic constructor fn returning a BOXED
// generic struct (OFI-045 / OFI-224 v1.0 cutover). `new_bag<K: Hash+Eq+Copy>() -> Bag<K>` returns Bag<K>,
// which has a heap `[K]` field, so it is ERASED to a Value in C — the callee signature already erases it
// (fn_ret_ctype via is_value). But the bounded free-fn CALL site typed the result temp as `em_s{sid}`
// whenever fn_ret_struct[fi] >= 0, ignoring is_value — emitting `em_s1 c = <Value call>`, which the C
// compiler rejects (incompatible types). The call-result temp now gates em_s on st.is_value, matching the
// signature. RUN-identity vs the VM. Runs to bag.count = 3.
struct Bag<K: Hash + Eq + Copy> {
    items: [K]
    count: int

    fn add(mut self, x: K) {
        self.items.append(x)
        self.count = self.count + 1
    }
}


fn new_bag<K: Hash + Eq + Copy>() -> Bag<K> {
    return Bag<K> { items: [], count: 0 }
}


fn main() -> int {
    var b: Bag<int> = new_bag()      // a bounded generic ctor returning a boxed Bag<int>
    b.add(10)
    b.add(20)
    b.add(30)
    println("count={b.count}")       // 3
    return b.count                    // 3
}
