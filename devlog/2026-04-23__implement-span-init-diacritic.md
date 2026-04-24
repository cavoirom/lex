# Lex devlog 2 - 2026-04-23

## Goals

- Write `init_diacritic` and tests.
- Write `init_diacritic_tone` and tests.
- Understand Zig language syntax in new code.

## Development decisions

### Reference documents

- Store reference documents fonud during development in `articles` directory.
- Use PDF format, prefer the PDF provided by the website. Otherwise, use Safari reader mode and
  print as PDF.

### Line width

- Use 100 as consistent line width for code and documents.

## Zig knowledge

- `inline for` is used to know comptime struct.
- Can omit enum name when type is known.
- `switch` can have `else` for remaining cases. We don't need `break` to terminate switch, constrast
  to Java.

## Telex knowledge

- Added a diacritic for `đ`: _bar_.
- All vowels can take all tone.
- List of Vietnamese characters: https://en.wikipedia.org/wiki/Vietnamese_alphabet

## Code

- Assertion strategy when dealing with many parameters: use `switch` for main parameter to narrow
  the scope and use `assert` on each arm of the switch. Could use `if` for further narrowing.
