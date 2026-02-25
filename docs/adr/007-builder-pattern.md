# ADR 007: Builder Pattern Over Result Builder

**Status:** Accepted

## Context

Steps could be defined via a Swift result builder (`@FlowStepBuilder`) or via a method-chaining builder pattern (methods returning `Self`).

## Decision

The builder pattern (methods returning `Self`) is used for step construction.

- Steps are ordered and the builder pattern naturally expresses sequential chains.
- A result builder adds complexity (custom DSL, control flow limitations) for minimal ergonomic gain when steps are linear.
- The builder pattern composes well with trailing-closure syntax for `action:` and `assert:`.

## Consequences

- Step building is intuitive: `.step("a") { ... }.step("b") { ... }.run { ... }`.
- No custom DSL to learn or maintain.
- Conditional steps require standard `if/else` with intermediate variables rather than inline control flow.
