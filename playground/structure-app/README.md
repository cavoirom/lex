# Structure — Core + Shell macOS Input Method

A playground establishing the "core + shell" architecture for a macOS menubar-only input method. The core engine (`liblex`) is a Zig static library exposing a C ABI; the shell (`Lex.swift`) is a Swift macOS app that intercepts keyboard events via `CGEventTap` and calls the core through a bridging header. Same demo behavior as `minimal-app` — typing `ee` produces `ê`, `EE` produces `Ê`, a third `e` cancels — but restructured to mirror production patterns inspired by [Ghostty](https://github.com/ghostty-org/ghostty) and [librime/Squirrel](https://github.com/rime/squirrel).

## Architecture

```
┌─────────────────────────────────────────────┐
│  Shell: macos/Lex.swift                     │
│  NSApplication + NSStatusBar + CGEventTap   │
│  Synthetic event emission, modifier/app-    │
│  switch handling, backspace forwarding      │
│                    │                        │
│      process_key_event(char) ──────────┐    │
│      process_backspace()    ──────────┐│    │
│      reset_state()          ─────────┐││    │
└──────────────────────────────────────┼┼┼────┘
                                       │││ C ABI (src/liblex.h)
┌──────────────────────────────────────┼┼┼────┐
│  Core: src/liblex.zig                │││    │
│  State machine:                      │││    │
│    idle → one_e → circumflex → literal      │
│  Tracks first-e case, gap distance,         │
│  and emits backspaces + replacement chars   │
└─────────────────────────────────────────────┘
```

## Prerequisites

- **Zig ≥ 0.15.2** (master recommended) — [download](https://ziglang.org/download/)
- **Xcode Command Line Tools** — `xcode-select --install`
- **macOS 26** (Tahoe)

## Project Structure

```
structure-app/
├── src/
│   ├── liblex.zig             # Core state machine (C library)
│   └── liblex.h               # C bridging header
├── macos/
│   ├── Lex.app/
│   │   └── Contents/
│   │       └── Info.plist     # LSUIElement=true (menubar-only)
│   └── Lex.swift              # macOS app shell
├── build.zig                  # Zig build script (full pipeline)
├── build.zig.zon              # Zig build manifest
└── .tool-versions             # Version management (zig master)
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

This is a **demo-grade** application:

- **Multi-key sequence, not single-key remap** — the state machine transforms `ee` → `ê`, not individual keystrokes. A third `e` cancels the circumflex and emits the original letters.
- **Secure input fields block the tap** — password fields and other secure text inputs disable event taps (by design).
- **Non-US layouts / IME not handled** — only tested with standard US keyboard layout.
- **Auto-repeat** — holding `e` will repeatedly cycle through states, which may behave differently from native key repeat.
- **No Dock icon** — `LSUIElement=true` means the app only appears in the menubar.
- **Gap tolerance** — up to 255 non-`e` alphanumeric characters can appear between the first and second `e` while preserving state; after that, state resets.
