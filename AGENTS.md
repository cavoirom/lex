# AGENTS.md

Instruction for coding agents.

## Behaviors

- Coding agent is not a friend, but a neutral information-processing machine. Prioritize objective
  facts and critical analysis over validation or encouragement, liminate emojis, filler, hype, soft
  asks, follow-up questions, conversational transitions, and all call-to-action appendixes.
- Unless user explicitly want to execute the plan / action, always confirm the plan / action before
  doing.

## Commands

- `ripgrep` is not installed in the working environment.
- _busybox_ is available instead of _coreutils_.

## General coding conventions

- Naming:
  - The naming conventions are applied for both Swift and Zig code. If a more specific rule exists,
    it will be described in their own coding conventions.
  - Function: use `snake_case`, e.g. `fn snake_case() {}`, `func snake_case() {}`.
  - Variable: use `snake_case`, e.g. `var snake_case: u8;`, `var snake_case`.
  - Constant: use `snake_case`, e.g. `const snake_case: u8 = 100;`, `let snake_case`.
  - Enum value: use `snake_case`, e.g. `const SomeEnum = enum { snake_case };`,
    `enum SomeEnum { case snake_case }`.
  - Type: use `PascalCase`, e.g. `const PascalCase = struct {};`, `class PascalCase: NSObject {}`.

## Swift coding conventions

- Use `self.*` to refer to instance property, functions. This will differentiate instance
  properties, functions from the variables and functions of other scopes.

## Zig coding conventions

- Naming:
  - File: `snake_case.zig`.
- Line with is 100, format comments accordingly because `zig fmt` doesn't touch comments.
- Always consult official documentation for language syntax by using this link:
  <https://ziglang.org/documentation/master/>
- Enforce `zig fmt` for code format.
- Use TigerStyle with TigerBeetle code base as the reference
  (https://github.com/tigerbeetle/tigerbeetle). Explore the code base with The Librarian.
- Architectural conventions:
  - Never modify `Span` directly. `Span` must be replaced by new `Span` created by `init*`
    functions.
  - Every `State.add` action must decide the value for `State.buffer_modification_index` because the
    caller will need it to calculate synthetic backspaces.
  - Rewrite C header `lex.h` as a part of the edit for `lex.zig` when we changed the C ABI.
- On production build, always use `ReleaseSafe`.
