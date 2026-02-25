# User's Guide: Overview

*Part of the [SwiftUIFlowTesting User's Guide](../README.md) series.*

## What SwiftUIFlowTesting Does

SwiftUIFlowTesting is a Swift Package Manager library for testing multi-step SwiftUI flows entirely in-process. Instead of launching the app via XCUITest, you:

1. Create an `@Observable` model with intent methods (the same methods your buttons call)
2. Build a sequence of steps that call those methods
3. Run the flow — each step renders the view and calls your snapshot/assertion closure

The result is fast, parallelizable, deterministic UI flow tests that don't seize your Mac.

## Why Not XCUITest?

| | XCUITest | SwiftUIFlowTesting |
|---|---|---|
| **Speed** | Slow (app launch per test) | Fast (in-process) |
| **Parallelism** | Serial (automation lock) | Fully parallel |
| **Machine lock** | Yes | No |
| **Determinism** | Flaky (timing, animations) | Deterministic |
| **Setup** | UI test target + app bundle | Test target only |

XCUITest remains valuable for a small set of true e2e tests that validate system integration (windows, menus, keyboard shortcuts). SwiftUIFlowTesting handles everything else.

## Design Goals

- **Zero external dependencies** — the library imports only SwiftUI and Foundation. Your test target brings [SnapshotTesting](https://github.com/pointfreeco/swift-snapshot-testing).
- **In-process** — no app launch, no simulator automation. Tests run as regular Swift Testing tests.
- **Model-driven** — tests call the same intent methods your views call. No gesture injection, no accessibility identifiers needed.
- **Snapshot-agnostic** — the `run(snapshot:)` closure is yours. Wire up SnapshotTesting, write to disk, or just assert on model state.

## How It Complements SnapshotTesting

SnapshotTesting captures a single view state. SwiftUIFlowTesting adds the flow dimension — driving a model through multiple states and capturing snapshots at each step. Together they give you visual regression testing across entire user journeys.

```
Model state A → Snapshot A
     ↓ (intent method)
Model state B → Snapshot B
     ↓ (intent method)
Model state C → Snapshot C
```

## Next Steps

- [Quick Start](USER_GUIDE_QUICK_START.md) — install and write your first test
- [AI Guide](USER_GUIDE_AI_GUIDE.md) — configure AI agents to generate flow tests
- [Git Snapshots](USER_GUIDE_GIT_SNAPSHOTS.md) — store snapshot images in version control
- [API Reference](API_SPEC.md) — complete type and method reference
