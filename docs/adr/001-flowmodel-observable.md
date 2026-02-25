# ADR 001: FlowModel Requires AnyObject + Observable

**Status:** Accepted

## Context

The library needs a protocol to mark model types that can be driven through UI flows. SwiftUI's Observation framework (`@Observable`) is the modern standard for reactive state in SwiftUI apps targeting iOS 17+ / macOS 14+.

## Decision

`FlowModel` requires both `AnyObject` and `Observable`:

```swift
public protocol FlowModel: AnyObject, Observable {}
```

- `Observable` ensures views using `@State` / `@Bindable` work correctly when the tester renders them, and property changes propagate without `ObservableObject` / `@Published` boilerplate.
- `AnyObject` is implied by `Observable` but stated explicitly for clarity: models are reference types mutated in-place by step actions.

## Consequences

- Apps targeting older OS versions with `ObservableObject` would need a trivial retroactive `Observable` conformance.
- All conforming types must be classes, which is the natural fit for mutable state containers driven through multi-step flows.
