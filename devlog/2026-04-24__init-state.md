# Lex devlog 3 - 2026-04-24

## Goals

- Write `init` for State. The `init` must receive a pointer from allocated memory and initialize the
  State on that buffer.

## Zig knowledge

- The `[16]Span` is a fixed array of Spans. All items must be initialized at the construction.
- Namespaced function such as `State.init` is Zig only term. C has no namespace. We must create a
  wrapper such as `lex_state_init`.
- Need export _size_ and _alignment_ of the struct for memory allocation.

## Code

- To run Swift tests, we must introduce SPM to our code base. Add 2 file: `Package.swift` and
  `macos/LexTests.swift`.

## Technical debts

- Alignment contract?
- Swift SPM?

## Tomorrow

- Add C header for liblex.
- Add Swift tests to test memory allocation and Swift-Zig interoperate.
