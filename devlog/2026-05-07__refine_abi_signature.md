# Lex devlog 6 - 2026-05-07

## Goals

- Refine C ABI signature and asserts.
- Improve Lex program specification. It is valuable if we want to rewrite the app in other
  technologies. Finished the diacritics section.

## Zig knowledge

- Use `assert(@intFromPtr(p) % @alignOf(State) == 0)` to quick check the alignment correctness of
  the pointer.

## Technical debts

- ~~What is `*anyopaque`?~~ A pointer to allocated memory without knowledge about its size and
  alignment.
