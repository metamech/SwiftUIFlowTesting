# ADR 003: Steps Carry [FlowAssertion] Not a Single Closure

**Status:** Accepted

## Context

Multiple assertions per step are common — checking screen state, button enabled state, and error state. A single closure bundles all assertions together, losing individual labels for diagnostics.

## Decision

Each step carries an array `[FlowAssertion<Model>]` where each `FlowAssertion` has a `label` and a `body` closure.

- Multiple assertions per step are first-class, each with its own label for diagnostics.
- A single assertion still works via the convenience `step(_:action:assert:)` overload.
- An empty array (the default) means no assertions.

## Consequences

- Assertion failures can report which specific assertion failed by label.
- The `step(_:action:assert:)` overload requires both `action:` and `assert:` (no default action) to avoid ambiguity with the `step(_:action:assertions:)` overload.
