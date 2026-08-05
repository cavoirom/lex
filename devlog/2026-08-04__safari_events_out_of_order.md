# The Safari text box that ate Vietnamese characters

Lex had a bug with an unusually specific appetite. Sometimes it ate Vietnamese
characters, but only inside web pages in Safari.

Typing `nguyee` should produce `nguyê`. Instead, the input briefly showed
`nguyeê`, then settled on `nguye`. The `ê` was inserted and immediately deleted.
Another sequence, `hoanx`, should produce `hoãn`, but could produce `hoaã`
instead.

The Zig input engine was returning the right edit. The macOS event tap was
posting events in the right order. Safari was still applying them in the wrong
order.

This is the story of how all three statements can be true at once.

## The clues pointed inside Safari

The failure was intermittent, but its boundary was unusually sharp:

- It affected ordinary HTML `<input>` elements, not just JavaScript-heavy
  editors.
- It affected Safari website content, but not Safari's URL field.
- Other macOS applications worked normally.
- Closing a Safari window and opening another one could make the problem
  disappear.

That last clue initially looked like random browser weirdness. Together, the
clues separated two text systems that happen to be drawn in the same window.
Safari's URL field is a native AppKit text control. A website input is edited
through WebKit and, usually, a separate Web Content process.

The problem was therefore unlikely to be the Vietnamese rules in
[`src/lex.zig`](src/lex.zig). It was more likely to be the boundary between the
global keyboard event tap and WebKit's text editor.

## How Lex normally edits text

Lex observes physical key-down events with a Quartz event tap. The event is sent
to the Zig engine, which returns a retrospective edit: remove some characters
immediately before the caret, then insert a replacement string.

For example:

| Typed input | Existing text | Engine edit           | Result  |
| ----------- | ------------- | --------------------- | ------- |
| `nguyee`    | `nguye`       | delete 1, insert `ê`  | `nguyê` |
| `hoanx`     | `hoan`        | delete 2, insert `ãn` | `hoãn`  |

Historically, [`macos/Lex.swift`](macos/Lex.swift) implemented that edit as a
sequence of synthetic keyboard events:

```text
Backspace × N → insert replacement
```

This works in native macOS text controls. It also looks sensible: post the
deletion events first, post the replacement second, and the application should
see them in that order.

Safari demonstrated the dangerous word in that sentence: "should."

## Events can arrive in order and take effect out of order

Several attempted fixes made the behavior easier to understand.

First, Lex also intercepted key-up events and suppressed physical key-ups
corresponding to consumed key-downs. This fixed a suspicious event lifecycle,
but did not change the Safari failure. The unmatched key-up was untidy, not
causal.

Next, Lex tried replacing Backspace with selection:

```text
Shift+Left × N → insert replacement over the selection
```

Typing `nguyee` then produced `nguyeê` with the new `ê` highlighted. This was
useful evidence. Safari had inserted the replacement first and applied
Shift+Left afterward, even though Lex had posted the selection events first.

The third attempt removed the synthetic insertion event. Lex posted Backspace
through the event-tap proxy, changed the Unicode text carried by the original
physical key-down, and returned that event from the callback. Quartz guarantees
that proxy-posted events enter the event stream before the event returned by the
callback.

The bug remained. `ê` appeared, then the earlier Backspace removed it.

At this point the low-level ordering was no longer the interesting ordering.
Quartz was delivering events correctly. Safari's web-content editing pipeline
was interpreting the deletion and insertion as separate commands and committing
their effects asynchronously. Ordering at the CGEvent boundary did not guarantee
ordering at the WebKit editing boundary.

No rearrangement of separate Backspace, navigation, and insertion events could
make that contract reliable. Adding a delay would only turn the race into a
slower race while blocking the global keyboard event tap.

## The fix: select synchronously, then perform one edit

The working fix avoids sending Safari a separate keyboard deletion command.

There is a small trap hiding inside the phrase "when Safari is focused." The
first implementation asked `NSWorkspace` for the frontmost application, then
asked the system-wide Accessibility object for the focused element. Those are
two separate observations of global state. An application switch between them
could produce a wonderfully cursed result: the first observation says Safari,
while the second points at a text field in another application.

Fortunately, the intercepted key event already knows where it is going. Quartz
stores the destination process in `eventTargetUnixProcessID`. Lex uses that PID
as the anchor for the entire Safari operation:

1. Reads `eventTargetUnixProcessID` from the physical key-down.
2. Resolves that PID to an `NSRunningApplication` and checks for Safari's bundle
   identifier, `com.apple.Safari`.
3. Creates Safari's application Accessibility object with
   `AXUIElementCreateApplication`.
4. Asks that application object for its focused element with
   `kAXFocusedUIElementAttribute`.
5. Reads the focused element's `kAXSelectedTextRangeAttribute` as a `CFRange`.
6. Moves the start of that range backward by the engine's deletion count.
7. Sets the resulting range through the Accessibility API.
8. Changes the Unicode text of the original physical key-down to the engine's
   replacement.
9. Returns that one key-down to the process named by the same event.

This matters because Safari is not one process wearing one hat. The browser UI
and the website can live in different processes. WebKit joins the Web Content
Accessibility tree to Safari's application tree with remote Accessibility
elements, so asking Safari's application object for its focused element can
still reach an HTML `<input>` in Web Content.

The focused HTML element may report a Web Content PID rather than Safari's PID.
That is expected. Its place in Safari's Accessibility tree establishes the
relationship; comparing the two PIDs would incorrectly reject the exact fields
this fix exists to handle.

The essential operation looks like this:

```text
key target:   Safari PID
AX root:      Safari application
focused:      Web Content input

caret:        nguy[e|]
AX selection: nguy[e]
key-down:         ê
result:       nguyê
```

The Accessibility range update is synchronous. By the time the event-tap
callback returns, the old text is already selected. Safari then receives one
keyboard editing command: insert the replacement at the current selection. There
is no synthetic Backspace or late Shift+Left command left for WebKit to reorder.

Lex deliberately does not assign the field's entire value through Accessibility.
Returning a real key event lets Safari perform the replacement through its
normal input path, which is important for web pages that observe keyboard and
input events. It also avoids rebuilding the field value and manually restoring
its caret.

## Failure needs to be boring

Accessibility support is not identical across every editable element. Password
fields and custom canvas-based editors may not expose a writable selected-text
range. The fix therefore has narrow guards:

- The special path is used only when the key event's target PID resolves to
  Safari. Other applications keep the established synthetic-event behavior.
- The focused element is requested from that Safari process's application
  Accessibility object, not from a second system-wide focus snapshot.
- The reported accessibility values must have the expected `AXUIElement`,
  `AXValue`, and `CFRange` types.
- The caret must be a zero-length selection and must have enough preceding
  characters to cover the requested edit.
- If any check fails, Lex resets its engine state and passes through the
  physical character instead of guessing and deleting user text.

Accessibility calls are synchronous inter-process calls, which introduces
another less exciting failure mode: an unresponsive Safari process could block
the event-tap callback. macOS normally gives Accessibility messaging a timeout
measured in seconds. That is far too long for code sitting in the global
keyboard path, so Lex sets the process-wide Accessibility timeout to 100
milliseconds. A timeout becomes a harmless literal keystroke instead of a frozen
keyboard.

## What actually fixed the bug

The final change was not "send the same events in a better order." Every version
of that approach still depended on WebKit honoring the semantic order of
independent keyboard commands.

The fix was to stop expressing one logical replacement as multiple keyboard
commands. Accessibility establishes the range synchronously, and a single
returned key-down performs the edit. The implementation also gives both
operations the same application identity: the PID already attached to that
key-down.

After that change:

```text
nguyee → nguyê
hoanx  → hoãn
```

The broader lesson is small but useful: event-stream order and application-state
order are different things, and "the focused application" is only meaningful at
a particular moment. When a boundary processes commands asynchronously,
correctness usually comes from reducing the number of commands crossing that
boundary and carrying one identity through the whole operation, not from
becoming more creative about timing.
