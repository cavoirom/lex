# Lex devlog 4 - 2026-04-27

## Goals

- Write some first steps for `lex_add` to understand the function identity.
- Try raw memory allocation and simple tests for `lex_add`.

## Zig knowledge

- `*const State`: read-only pointer. Could not write to the memory.
- `*State`: mutable pointer, could write to the memory. In case of `lex_add`, `*State` is correct.

## Telex knowledge

- At this stage, I want `lex_add` based on the input character to determine the intention, then I
  will have a checklist for each intention.
- Have an overview about possible intentions.

## Tomorrow

- Add assert to `lex_add`.
- Add C header for liblex.
- Add Swift tests to test memory allocation and Swift-Zig interoperate.
