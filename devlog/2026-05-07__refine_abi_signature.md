# Lex devlog 6 - 2026-05-07

## Goals

- Refine C ABI signature and asserts.

## Zig knowledge

- Use `assert(@intFromPtr(p) % @alignOf(State) == 0)` to quick check the alignment correctness of
  the pointer.

## Technical debts

- ~~What is `*anyopaque`?~~ A pointer to allocated memory without knowledge about its size and
  alignment.
