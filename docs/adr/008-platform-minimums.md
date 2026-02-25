# ADR 008: Platform Minimums (iOS 17+ / macOS 14+)

**Status:** Accepted

## Context

The library requires the Observation framework (`@Observable`), which shipped with iOS 17, macOS 14, tvOS 17, watchOS 10, and visionOS 1.

## Decision

| Platform | Minimum | Reason |
|----------|---------|--------|
| iOS | 17.0 | `@Observable` (Observation framework) |
| macOS | 14.0 | `@Observable` (Observation framework) |
| tvOS | 17.0 | `@Observable` (Observation framework) |
| watchOS | 10.0 | `@Observable` (Observation framework) |
| visionOS | 1.0 | Ships with Observation framework |

## Consequences

- Apps targeting older OS versions cannot use the library directly.
- The Observation framework provides automatic change tracking without `@Published`, simplifying both the library and consumer code.
