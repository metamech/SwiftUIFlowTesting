# ADR 002: FlowStep.action Is Synchronous

**Status:** Accepted

## Context

Flow testing exercises model intent methods (e.g., `model.proceedToPayment()`), which are synchronous state mutations. The model owns async work internally; tests typically don't need to await it during the step action.

## Decision

`FlowStep.action` is `@MainActor @Sendable (Model) -> Void` — synchronous, non-throwing.

- If a consumer needs async setup between steps, they do so before constructing the tester or between separate tester runs.
- Keeping the core synchronous avoids forcing `async` on every test and keeps the runner simple.
- An experimental `asyncStep` variant is available under `@_spi(Experimental)` for cases where async actions are needed.

## Consequences

- The synchronous `run(snapshot:)` method stays simple and non-async.
- Async support is opt-in via `@_spi(Experimental)` without breaking the stable API.
