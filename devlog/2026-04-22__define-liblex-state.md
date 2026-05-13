# Lex devlog 1 - 2026-04-22

## Goals

- Define the engine state and test them.
- Understand the technical term, Zig language syntax used in the code.

## Telex knowledge

- Diacritics: dấu của ký tự.
- Tone: dấu thanh.

The name of diacritics and tones were taken from Wikipedia:

- https://en.wikipedia.org/wiki/Vietnamese_phonology
- https://en.wikipedia.org/wiki/Diacritic
- https://en.wikipedia.org/wiki/Telex_(input_method)

## Zig knowledge

- Must use `extern` to have C ABI guarantee. The `extern` only affect to the current struct, we must
  specify `extern` to all structs that we want C ABI compatible.
- Enum is backed by a tagged type, e.g. `u4` (4 bits unsigned-integer).
- If we want C ABI compatible enum, we must tag it with C compatible type, it could be Zig type,
  just be compatible, e.g. u8 (uint8_t), u16 (uint16_t).
- Found API: https://ziglang.org/documentation/master/std/#std.ascii.isAlphabetic to check alphabet
  character.
- Know how to use `@import`: `const std = @import("std");`.
- `expectEqual` return error union, we must handle error or use `try` to properly throw the error.
- What is `'A'...'Z', 'a'...'z'`?

## Code

- We define nearly good data structure. Now we need to think about initialize, validate the
  structure based on our design: caller allocated memory.
- Use `init` function to create struct instance, include validation in `init`.
- Use `assert` for validation, treat invalid parameters as programming error, non-recoverable.
- Write test near the implementation code.
- Use `init` for the default usage, `init_<more_parameter>` for alternative usage.

## Technical debts

- ~~`inline for`~~.
- ~~`@import`~~.
- ~~Error union? A normal type combine with `!` (error), force the receiving side to handle the
  error.~~

## Tomorrow

- ~~Write `init_diacritic` and tests~~.
