# ADR 005: environmentPatch Requires @MainActor

**Status:** Accepted

## Context

`FlowConfiguration.environmentPatch` manipulates `EnvironmentValues`, a SwiftUI type used during view construction. SwiftUI view construction happens on the main actor.

## Decision

The `environmentPatch` closure is typed as `@MainActor @Sendable (inout EnvironmentValues) -> Void`.

## Consequences

- `FlowConfiguration` itself remains `Sendable` (the closure captures are `@Sendable`).
- The patch is only callable from `@MainActor` contexts, which is always the case since `FlowTester` is `@MainActor`-isolated.
