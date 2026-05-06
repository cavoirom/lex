# Lex devlog 5 - 2026-05-06

## Goals

- Implement backspace and tests.
- Implement diacritic handling for 'A', 'E', 'O'. Missing tests.

## Zig knowledge

- Use `pub` if we want the function can be used outside the current Zig file.
- No API to compare character ignore case in std, they have it for string.
- It's OK to put assert inside if statement.
- Know how to use optional, especially syntax: `if (optional) |value| {}`.

## Telex knowledge

- Diacritic can be overridden, e.g. `ă`, input `a`, result `â`.

## Lex knowledge

- `literal_index` is only valid in `telex` mode because `literal` mode don't need it. This will
  reduce the handling complexity.
- Strictly initialize Span by `init*`.
