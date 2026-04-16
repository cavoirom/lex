# Prototype — Span-based Vietnamese Telex IME

A playground prototype for a Vietnamese Telex input method on macOS. The core engine (`liblex`) is a Zig static library that models each rendered character as a **span** (base + modifier + tone), handling the full Telex input set: all vowels with diacritics (â, ă, ê, ô, ơ, ư), tones (sắc, huyền, hỏi, ngã, nặng), đ, cancellation logic, `gi`/`qu` onset reclassification, and `ươ` auto-fill. The shell (`Lex.swift`) is a macOS menubar app that intercepts keystrokes via `CGEventTap`, feeds them to the engine, and applies a **diff** against the currently rendered text — emitting only the minimal sequence of synthetic backspaces followed by a single multi-character insertion event to update the active application.

## Architecture

The system is split into two layers communicating through a C ABI:

- **Core (`src/liblex.zig`)** — A span-based composition engine. Each keystroke mutates an array of `Span` structs (base letter, modifier, tone, flags). The engine handles modifier application (doubled vowels `aa`→`â`, `w`→`ơ`/`ư`/`ă`, `dd`→`đ`), tone placement following Vietnamese linguistic rules (region analysis: onset → nucleus → coda, with semi-vowel coda detection), cancellation (repeating a filled modifier/tone strips it and enters literal mode), `gi`/`qu` onset binding, and `ươ` auto-fill. Unicode output is produced via lookup tables covering all 12 vowel bases × 6 tone variants in both cases. The engine exposes `add`, `backspace`, `reset`, `get_composed_utf16`, `init_state`, and `state_size`.

- **Shell (`macos/Lex.swift`)** — A menubar-only macOS app (`LSUIElement=true`) that owns the engine state and a rendered-text snapshot. On each keystroke it calls the engine, reads the new composed UTF-16, and diffs it against the snapshot to compute the minimal edit (common-prefix comparison). Replacement characters are emitted in a single multi-character `CGEvent` to reduce flicker. Synthetic events are tagged (`0x4C4558`) to avoid feedback loops. The shell resets engine state on app switches, mouse clicks, modifier keys (Cmd/Ctrl/Alt), navigation keys (arrows, Home/End, Tab, Escape, Return, forward delete), and tap-disabled events. A global hotkey (Ctrl+Opt+Space) toggles Vietnamese input on/off with audio feedback.

- **FFI bridge (`src/liblex.h`)** — C-compatible header declaring the engine API. Swift calls into the Zig static library through this bridging header. The engine is stateless from the caller's perspective — Swift allocates the opaque state buffer (`state_size()` bytes) and passes it to every call.

## Prerequisites

- **Zig ≥ 0.16.0** (master recommended) — [download](https://ziglang.org/download/)
- **Xcode Command Line Tools** — `xcode-select --install`
- **macOS 26** (Tahoe)

## Project Structure

```
prototype-app/
├── src/
│   ├── liblex.zig              # Span-based Telex engine (C library)
│   └── liblex.h                # C bridging header
├── macos/
│   ├── Lex.app/
│   │   └── Contents/
│   │       └── Info.plist      # LSUIElement=true (menubar-only)
│   └── Lex.swift               # macOS app shell (diff-based rendering)
├── build.zig                   # Zig build script (full pipeline)
├── build.zig.zon               # Zig build manifest
└── .tool-versions              # Version management (zig master)
```

## Build

The `build.zig` script automates the entire pipeline — building the Zig static library, re-packing the archive (Zig master workaround for non-8-byte-aligned archive members), compiling Swift, and ad-hoc codesigning — in a single command:

```sh
zig build
```

To build and immediately launch the app:

```sh
zig build run
```

Or run the binary directly to see console output:

```sh
./macos/Lex.app/Contents/MacOS/Lex
```

### Manual steps (for reference)

<details>
<summary>Expand manual build steps</summary>

#### Step 1: Build the Zig static library

```sh
zig build
```

This produces `zig-out/lib/liblex.a`.

#### Step 2: Re-pack the archive (Zig master workaround)

Zig master produces archives with non-8-byte-aligned members that Apple's linker rejects. Re-pack with the system `ar`:

```sh
cd zig-out/lib && \
  tmp=$(mktemp -d) && \
  (cd "$tmp" && ar x "$(cd - && pwd)/liblex.a" && chmod 644 *.o && /usr/bin/ar rcs "$(cd - && pwd)/liblex.a" *.o) && \
  rm -rf "$tmp" && \
  cd ../..
```

#### Step 3: Compile Swift and link with the Zig library

```sh
swiftc macos/Lex.swift \
    -import-objc-header src/liblex.h \
    -Lzig-out/lib -llex \
    -o macos/Lex.app/Contents/MacOS/Lex
```

#### Step 4: Sign the app (ad-hoc, for local development)

```sh
codesign -f -s - macos/Lex.app
```

</details>

## Signing

### Ad-hoc (local development)

Ad-hoc signing is sufficient for local testing and is performed automatically by `zig build`:

```sh
codesign -f -s - macos/Lex.app
```

### Hardened Runtime (for notarization)

Requires a signing identity and entitlements:

```sh
codesign -f -s "YOUR_IDENTITY" \
    --options runtime \
    macos/Lex.app
```

#### Finding your signing identity

List available identities:

```sh
security find-identity -v -p codesigning
```

## Permissions

**Accessibility** is required for `CGEventTap` to intercept keyboard events. This is a TCC (Transparency, Consent, and Control) permission — not an entitlement.

On first launch, the app calls `AXIsProcessTrustedWithOptions()` which prompts the user. Grant access in:

> **System Settings → Privacy & Security → Accessibility**

Then relaunch the app.

## Known Limitations

This is a **prototype-grade** application:

- **Synthetic event fragility** — the backspace+multi-char-insert approach is unreliable in terminal emulators, Electron-based apps, and secure input fields where `CGEventTap` may be blocked or events reordered. Some apps may not handle multi-character `keyboardSetUnicodeString` correctly.
- **Single-char assumption** — the engine expects one text-producing `UniChar` per `keyDown` event, which may fail for complex dead-key layouts or surrogate pairs.
- **`ươ` auto-fill edge cases** — the auto-fill heuristic for `ươ` only triggers when a coda consonant is present and may not cover all valid Vietnamese syllable patterns.
- **Secure input fields block the tap** — password fields and other secure text inputs disable event taps by design.
- **Non-US layouts not handled** — only tested with standard US keyboard layout.
- **No Dock icon** — `LSUIElement=true` means the app only appears in the menubar.
