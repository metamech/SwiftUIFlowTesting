# ADR 004: Sendable Strategy for Strict Concurrency

**Status:** Accepted

## Context

Swift 6.2 strict concurrency requires explicit `Sendable` conformance for types crossing actor boundaries. The library must work correctly under these rules.

## Decision

- `FlowStep` is `Sendable`. Its closures are `@MainActor @Sendable`.
- `FlowAssertion` is `Sendable`. Its body closure is `@MainActor @Sendable`.
- `FlowConfiguration` is `Sendable`. Its `environmentPatch` closure is `@MainActor @Sendable`.
- `FlowStepResult` is `Sendable` (all stored properties are value types).
- `FlowTester` is `@MainActor`-isolated and is **not** `Sendable`. It must not cross actor boundaries. This is correct because SwiftUI view construction and model mutation must happen on `@MainActor`.
- `FlowModel` does not add an explicit `Sendable` requirement to avoid over-constraining models that hold non-Sendable internal state.

## Consequences

- All value types in the library are safe to pass across concurrency domains.
- `FlowTester` construction, step building, and execution must all happen on `@MainActor`, which is natural for test code annotated `@MainActor` or `@Suite(.serialized)`.
