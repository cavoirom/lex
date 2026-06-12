# ios-app — Lex iOS keyboard extension

An iOS custom keyboard for the Lex Telex Vietnamese input engine. It adapts the
macOS app's idea — engine-driven synthetic-backspace + replacement
reconciliation with `liblex` as the single source of truth — to a custom
keyboard extension. There is no `CGEventTap`: the extension *is* the keyboard,
so it reconciles against the host text field through `UITextDocumentProxy`
(`insertText` / `deleteBackward`) instead of synthesising key events.

## Architecture

```
╭──────────────────────────────────────────────────────────╮
│ KeyboardView (UIKit)  — from-scratch US-QWERTY, 3 planes  │
╰───────────────┬──────────────────────────────────────────╯
                │ KeyAction (tap events)
╭───────────────▼──────────────────────────────────────────╮
│ KeyboardViewController (UIInputViewController)             │
│  reconciliation: delete N + insert composed replacement   │
╰───────────────┬───────────────────────┬──────────────────╯
        C ABI   │                        │ textDocumentProxy
╭───────────────▼─────────╮   ╭──────────▼──────────────────╮
│ LexEngine (Swift wrap)  │   │ host app text field          │
│ over liblex C ABI       │   ╰──────────────────────────────╯
╰─────────────────────────╯
```

- The engine knows nothing about iOS; the UI knows nothing about Telex; the
  view controller is the only place that reconciles engine state with text
  proxy operations.
- Per letter tap (ASCII a–z/A–Z): feed the engine, `deleteBackward` the
  engine-reported synthetic-backspace count, then insert the composed
  replacement. Digits/symbols/space/return reset the composition and insert
  literally. Lex is always Telex; to type plain Latin or another language the
  user switches keyboards with the globe key.
- An external-change guard (compare `documentContextBeforeInput` against the
  suffix we believe we own) resets the engine when the cursor or text moves
  under us. The keyboard is **not** reset on every `textDidChange`, which would
  break multi-key composition.

## Project layout

```
playground/ios-app/
├── src/                  # liblex snapshot (lex.zig + lex.h), self-contained
├── ios/
│   ├── Lex.swift         # container app (enable-instructions only)
│   ├── Keyboard.swift    # extension: UIInputViewController + UI + engine wrap
│   ├── project.yaml      # xcodegen spec (app + app-extension)
│   ├── Generated/        # xcodegen-injected Info.plists (generated)
│   └── Lex.xcodeproj/    # xcodegen output (generated)
├── build.zig / build.zig.zon
└── README.md
```

`liblex` is immutable upstream (`../../src`). `src/` here is a self-contained
snapshot of that engine; do not edit it.

## Prerequisites

- **Zig 0.15.2** (`.tool-versions`). Builds the `liblex` iOS slices; works on
  Linux and macOS.
- **macOS + Xcode 26** (iOS 26 SDK) for the app/extension build and the
  XCFramework.
- **XcodeGen** (`brew install xcodegen`) — generates the `.xcodeproj` so Xcode
  the IDE is never required.
- Target: **iPhone 11 Pro, iOS 26** (simulator and device). Dev machine for the
  Apple steps is assumed to be Apple Silicon (M1 Pro).

## Build

### On Linux (engine only)

```sh
zig build          # cross-compiles liblex device + simulator slices
zig build test     # runs the liblex unit tests on the host
```

This produces, under `zig-out/`:
`lib/ios-device/liblex.a`, `lib/ios-sim/liblex.a`, `include/lex.h`.
The Xcode-dependent steps print a notice and do nothing on Linux.

### On macOS (full app)

One command does slices → XCFramework → project generation → simulator build:

```sh
zig build app
```

Equivalent explicit steps:

```sh
# 1. Build the liblex iOS slices (device + simulator).
zig build

# 2. Assemble liblex.xcframework (repacks archives with Apple's ar, then
#    xcodebuild -create-xcframework). Output: zig-out/liblex.xcframework
zig build xcframework

# 3. Generate the Xcode project from the spec.
cd ios && xcodegen generate --spec project.yaml && cd ..

# 4. Build the app + keyboard extension for the iPhone 11 Pro simulator.
xcodebuild \
  -project ios/Lex.xcodeproj \
  -scheme Lex \
  -configuration Debug \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 11 Pro' \
  -derivedDataPath ios/build \
  CODE_SIGNING_ALLOWED=NO \
  build
```

### Run in the simulator

```sh
xcrun simctl boot "iPhone 11 Pro"
open -a Simulator
xcrun simctl install booted \
  ios/build/Build/Products/Debug-iphonesimulator/Lex.app
xcrun simctl launch booted com.cavoirom.lex.ios
```

Enable the keyboard inside the simulator: **Settings → General → Keyboard →
Keyboards → Add New Keyboard… → Lex**. Then in any text field long-press the
globe key and pick Lex. Lex always types Vietnamese (Telex); switch keyboards
with the globe key to type anything else.

### Build for a device (iPhone 11 Pro)

Device builds require code signing. Provide your Apple development team's
certificate subject `OU` as `DEVELOPMENT_TEAM` and let Xcode manage signing
automatically:

```sh
zig build xcframework
cd ios && xcodegen generate --spec project.yaml && cd ..
xcodebuild \
  -project ios/Lex.xcodeproj \
  -scheme Lex \
  -configuration Release \
  -sdk iphoneos \
  -destination 'generic/platform=iOS' \
  -derivedDataPath ios/build \
  -allowProvisioningUpdates \
  -allowProvisioningDeviceRegistration \
  DEVELOPMENT_TEAM=YOUR_TEAM_ID \
  build
```

Use the `OU` field from the Apple Development certificate subject as the Team ID
for `DEVELOPMENT_TEAM`. Do not copy the id shown in the `security find-identity`
display name; that value can differ from the certificate subject `OU` that
Xcode expects for automatic provisioning.

One way to inspect the certificate subject is:

```sh
security find-certificate \
  -c "Apple Development: your-apple-id@example.com" \
  -p \
  ~/Library/Keychains/login.keychain-db |
openssl x509 -noout -subject -nameopt sep_multiline
```

Use the printed `OU = ...` value as `YOUR_TEAM_ID`. The device must be
registered with that team; a free personal team works for local installs. For a
new device, build once with a concrete device destination, for example
`-destination 'platform=iOS,id=DEVICE_UDID'`, so
`-allowProvisioningDeviceRegistration` can register it.

### Install on a device

After a successful device build, install the built app with `devicectl`:

```sh
xcrun devicectl device install app \
  --device DEVICE_UDID \
  ios/build/Build/Products/Release-iphoneos/Lex.app
```

If the app path differs, find it with:

```sh
find ios/build -name Lex.app -type d
```

Launch the container app with the bundle id from `project.yaml`:

```sh
xcrun devicectl device process launch \
  --device DEVICE_UDID \
  com.cavoirom.lex.ios
```

If you changed `PRODUCT_BUNDLE_IDENTIFIER` in `project.yaml`, use that app
bundle id instead of `com.cavoirom.lex.ios`. Then enable the keyboard on the
iPhone in **Settings → General → Keyboard → Keyboards → Add New Keyboard… →
Lex**.

## Notes

- **No "Allow Full Access".** `RequestsOpenAccess` is `false`. Basic
  insert/delete needs no special access, so no App Group is used.
- **`liblex` cross-compiles on Linux.** It is pure Zig with a C ABI and no libc
  or Apple-SDK dependency. The slices are tagged `PLATFORM_IOS` (device) and
  `PLATFORM_IOSSIMULATOR` (simulator), both `minos` iOS 26.0.
- **Archive repacking.** Apple's linker rejects non-8-byte-aligned archive
  members produced by Zig, so each slice is repacked with the system `ar` during
  the `xcframework` step (on macOS, to use Apple's `ar`).
- **Stripped slices.** The iOS slices are built `ReleaseSafe` but with
  `strip = true`. This keeps the runtime safety checks while dead-code-removing
  Zig's panic stack-trace symbolizer, which references the dyld SPI
  `_dyld_get_image_header_containing_address` that the iOS SDK refuses to link
  against (an unstripped slice fails to link into the extension). On a panic the
  engine still aborts; it just cannot print a symbolicated trace.
- **Scope (v1).** Portrait only; no predictive bar, long-press alternates, swipe
  typing, or autocorrect. US-QWERTY layout with `123`/`#+=` planes, shift /
  caps-lock, backspace auto-repeat, and globe (next keyboard). Always Telex.
```
