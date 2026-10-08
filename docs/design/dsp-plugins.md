---
title: "DSP & Audio Plugins in Ingle"
nav_exclude: true
---

# DSP & audio plugins in Ingle — the plan

> **Status: RATIFIED (2026-10-08).** Karl accepted §4 calls 2–5 as recommended and **overruled call 1**:
> no hybrid phase — kplug and kui are rewritten as dedicated Ingle libraries from the start.
> Prerequisite OFI-229 (typed scalar maths at C speed) is **DONE**.

## 1. The goal

Write VST3 / AU / CLAP plugins in Ingle, the way the Obscene Audio catalog is written today on the
C++ stack:

| C++ today | What it is | Size | Ingle equivalent |
|---|---|---|---|
| **kasm** | JUCE-free DSP: FFT, IIR, oversampling, convolution, delay, smoothing, reverb, chorus, compressor, 303 synth modules, saturation | ~10.7k lines, 40 headers, 84 tests | `std/dsp` |
| **kplug** | plugin-format layer: params, sample-accurate automation, state, notes/MIDI → a CLAP plugin; clap-wrapper makes VST3 + AUv2 | ~5.5k lines | `std/plug` + a thin C shim |
| **kui** | UI toolkit drawing through CoreGraphics/CoreText, Obscene theme, knobs/meters/spectrum/EQ editors | ~9.2k lines | a Flare backend embedded in the host's window |

The C++ stack works and ships, so this is only worth it for what Ingle adds that C++ can't:
**a compiler-proven realtime guarantee** (§3.4) and contracts + tape on DSP code. Everything is staged
so that each phase ends in something runnable, and the C++ stack serves as the **oracle**, not as code we
link into: same parameter maths and state bytes as kplug, same DSP output as kasm (bit-exact), same pixels
as kui (its golden images).

## 2. Where Ingle stands (measured 2026-10-08)

- **Maths speed: fixed.** An f32 biquad over 100M samples: 2.29 s → **0.38 s** after OFI-229 (C: 0.33 s).
- **Data layout: already right.** `[f32]` is a packed native float buffer; f32 locals are C `float`s.
- **FFI: C → C works** (`extern "c"`, scalars/structs/buffers/opaque `Ptr`). **C → Ingle does not**:
  nothing can call *into* an Ingle function from C, and `inglec -o` only builds an executable with `main`.
- **The runtime has one heap context per program** (`static EmberRt g_em`), not thread-safe. A plugin
  is called from the host's audio thread *and* its main/UI thread.
- **Slices are read-only** — write-through slices were deliberately deferred (they need lifetimes).

## 3. The missing language/compiler pieces

### 3.1 Library output — `inglec --emit=lib`
Build a static library (`.a`) instead of an executable: no `main`, a one-time `ingle_init()` /
`ingle_shutdown()`, and **exported** functions with a plain C signature that C can call by name.

### 3.2 Exporting functions to C
The mirror of `extern "c"`: mark an Ingle function as callable from C, with a C-ABI signature
(scalars, `Ptr`, buffers). Symbols get a per-library prefix and everything else is hidden, so two Ingle
plugins loaded in one DAW can't collide.

### 3.3 Mutable views over host buffers
The host hands the plugin raw `float*` channels. DSP needs to read and **write them in place**, no copy.
Proposed: a `mut Slice<f32>` — a write-through view — that can only exist as a *parameter* or local (the
existing "a slice cannot escape" rule), so no lifetime inference is needed. The C shim turns
`(float*, n)` into one at the call boundary.

### 3.4 `realtime` functions — the differentiator
A function marked `realtime` is checked by the compiler to **never allocate, lock, block, print, do
I/O, spawn, or call anything that is not itself `realtime`** (or an `extern "c"` declared realtime).
This is the same "heap-free subset" the kernel work already mapped. It gives two things at once:
- **audio-thread safety, proven** — kasm can only *test* that `process()` is allocation-free; Ingle
  would *reject the program* if it isn't;
- **thread safety for free** — realtime code never touches the shared heap context, so the audio thread
  and the UI thread can't race on it.

### 3.5 Small items
`sin/cos/tan/exp/log/pow/tanh/sqrt/floor/fabs` on f32 and f64 as inline intrinsics; denormal flushing
(a realtime extern); later, SIMD (start with auto-vectorisation of typed loops; explicit vectors only if
measured necessary).

## 4. The five design calls (need Karl's decision)

1. **Order: Ingle-native from the start** *(Karl's call, overruling the recommended hybrid-first)*.
   kplug → `std/plug` and kui → a Flare backend are dedicated Ingle libraries; no phase links Ingle DSP
   into the C++ shell. Cost: the first plugin arrives later. Mitigations: the first plugin is minimal
   (gain/biquad, host-generic UI); plugins are exercised without kplug by `clap-validator` and a small C
   test host; kplug/kasm/kui are the behavioural oracles.
2. **Plugin format: CLAP through a thin C shim**, clap-wrapper for VST3/AU — exactly what kplug does now.
   CLAP is a pure C API, which suits Ingle. (clap-wrapper is C++ *build tooling* — a dependency to sign off.)
3. **`realtime` syntax:** a function modifier, `realtime fn process(...)`, reading like `pub fn`.
   Checked transitively; an `extern "c"` must also be marked `realtime` to be callable from one.
4. **Export syntax:** `export "c" fn name(...)`, the mirror image of `extern "c"`.
5. **UI:** a new **Flare backend** drawing via CoreGraphics into the host's `NSView`, with
   `obscene::Theme` ported to it — not a C wrapper around kui (its retained C++ View tree doesn't
   bridge cleanly). Early plugins use the host's generic parameter UI.

## 5. Phases

| Phase | Delivers | Exit test |
|---|---|---|
| **0** ✅ | OFI-229 — typed scalar maths at C speed | biquad within 1.2× of C |
| **1** ✅ | `export "c"` + `--emit=lib` (`66db37f`), `realtime` checking (`0e59530`), writable `mut Slice<T>` + buffer exports (`e479d62`), `std/math` + C-speed maths/array access (`103b64b`); exit test `tests/lib/biquad` | an Ingle gain + biquad `process()` driven by a C test host; realtime violations rejected — **met 2026-10-08** |
| **2** | `std/plug` core — CLAP in Ingle over a thin C shim: params (kplug's range maths), sample-accurate automation, state, bypass | an Ingle gain/filter plugin passes `clap-validator` and loads in a DAW (host-generic UI); clap-wrapper VST3/AU bundles |
| **3** | `std/dsp` — the kasm port, kasm as the bit-exact oracle (pffft stays C, via FFI) | kasm's 84 test cases reproduced |
| **4** | `std/plug` complete — notes/MIDI in+out, timers, VisualFeed/Handoff, blobs, audio files | the kplug demo + synth examples rebuilt in Ingle |
| **5** | Flare CoreGraphics backend embedded in the host view + Obscene theme + kui's widgets | an Obscene editor rendered within kui's golden-image tolerance |
