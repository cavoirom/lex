# Lex devlog 8 - 2026-05-13

## Goals

- Implement and tests apply rising.

## Zig knowledge

- More familiar with `while`, `for`, `switch`.
  - For with range: `for (0..10) |i| {}`, the upper bound is exclusive.
  - Switch can return value.
- _ReleaseSafe_ includes a runtime ~2MiB to handle safety behaviors.
- _ReleaseSmall_ will remove asserts, having asserts could help compiler optimize the code.
- _ReleaseFast_ will optimize for performance. Choose this when release the program.
- Use `*const Type` to provide read-only pointer for struct's functions.

## Code

- Write more helpers such as `Span.equals_ignore_case`, `State.pseudoword`.
- When using variable to describe something is existing, use: `something_exists: bool`,
  `things_exist`.
