# Lex devlog 7 - 2026-05-08

## Goals

- Implement all diacritics rules.
- Write complete tests for diacritics rules.

## Code

Research the code pattern to write more helpers:

- Get last span in `buffer_effective`: `State.buffer_effective_last(state: *State)`.
- Compare a span with a base character (ignore case) and diacritic, ignore tone:
  `Span.equals_ignore_case_and_tone(self: Span, c: u8, diacritic: Diacritic)`.
- Compare only base character: `Span.equals_base(base: u8)`.
