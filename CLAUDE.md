# CLAUDE.md — SwiftUIFlowTesting

## Purpose

SPM library providing in-process pseudo-e2e testing infrastructure for SwiftUI apps.
Drives UI flows via model intent methods, renders views, and exposes snapshot/assertion hooks —
all without XCUITest or launching the app.

## Platform & Tooling

- **Swift 6.2**, strict concurrency enabled
- **SPM library** — no Xcode project, no Makefile
- **Frameworks**: SwiftUI + Foundation only
- **Zero external dependencies** — consuming apps bring SnapshotTesting
- **Test framework**: Swift Testing (`@Test`, `@Suite`, `#expect`) — no XCTest in this repo

## Commands

```
swift build          # build the library
swift test           # run all tests
swiftlint            # lint (must pass before commit)
swift-format lint .  # check formatting
swift-format .       # apply formatting
```

## Core Types

| Type | Role |
|------|------|
| `FlowModel` | Protocol — marker for models that drive a SwiftUI screen/flow |
| `FlowViewFactory` | Protocol — builds a SwiftUI view for a given model |
| `ClosureFlowViewFactory` | Struct — closure-based `FlowViewFactory` convenience |
| `FlowStep` | Struct — one step in a flow (name, action, assertions) |
| `FlowConfiguration` | Struct — environment/snapshot config for a test run |
| `FlowTester` | Class — central runner: model + factory + steps → run |

## Package Boundary Rules

- `Sources/` must **never** import XCTest, SnapshotTesting, or any external package
- `Tests/` uses Swift Testing only — no XCTest
- Consuming apps wire SnapshotTesting into the `snapshot` closure at the call site

## Agent Roster

| Agent | Model | Role |
|-------|-------|------|
| architect | inherit | API design, protocol design, concurrency model, SPM structure |
| test-engineer | haiku | Test coverage, protocol conformance, builder-pattern testing |
| feature-implementer | sonnet | Test-first implementation of library types |
| git-ops | haiku | Branch management, commits, PRs |
| integration-tester | sonnet | Root-cause analysis when tests fail |
| swift-dependency-scanner | haiku | Verify zero-dep boundary, Sendable conformance |
| prompt-engineer | sonnet | Docs quality, CLAUDE.md maintenance, agent tuning |

## Workflow

- **Branches**: `<type>/<slug>` (e.g., `feature/flow-tester`, `fix/sendable-conformance`)
- **Quality gates**: `swift build` + `swift test` + `swiftlint` must pass before commit
- **Test-first**: write failing test, implement, verify green
- **No AI attribution** in commit messages

## Documentation

- `docs/API_SPEC.md` — API specification and type reference
- `docs/CONCEPT.md` — design philosophy and rationale
- `docs/INTEGRATION.md` — user guide for consumers using AI agents
- `docs/SNAPSHOTS.md` — snapshot storage in git
