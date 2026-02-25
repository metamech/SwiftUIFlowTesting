# ADR 006: Snapshot Closure Receives AnyView

**Status:** Accepted

## Context

The `run(snapshot:)` method needs to pass the rendered view to a consumer-provided closure. The concrete view type depends on the `Content` generic parameter and the environment wrapper, making it unwieldy to expose directly.

## Decision

The snapshot closure receives `AnyView`. The runner builds the concrete view via the `viewBuilder` closure, applies environment patches with `content.environment(\.self, env)`, then wraps the result in `AnyView`.

- The snapshot closure is provided by the consumer (e.g., wrapping `assertSnapshot`), which already accepts `AnyView` or `any View`.
- `AnyView` cost is negligible in a test-only context (no diffing, no animation).
- Avoiding `AnyView` would require the snapshot closure to be generic, which makes the `run` signature unwieldy and breaks the builder chain.

## Consequences

- Consumers don't need to know the concrete view type.
- No performance concern since this is test infrastructure, not production rendering.
