# CLAUDE.md — SwiftUIFlowTesting

## Purpose

SPM library providing in-process pseudo-e2e testing infrastructure for SwiftUI apps.
Drives UI flows via model intent methods, renders views, and exposes snapshot/assertion hooks —
all without XCUITest or launching the app.

## Platform & Tooling

- **Swift 6.2**, strict concurrency enabled
- **SPM library** — no Xcode project, no Makefile
- **Frameworks**: SwiftUI + Foundation only
- **Zero external dependencies** — consuming apps **may** bring SnapshotTesting for advanced snapshot strategies
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
| `FlowModel` | Protocol — `AnyObject & Observable` marker for testable models |
| `FlowAssertion` | Struct — labeled assertion closure for diagnostics |
| `FlowStep` | Struct — one step in a flow (name, action, assertions) |
| `FlowStepResult` | Struct — per-step result returned from `run()` |
| `FlowConfiguration` | Struct — environment patching config for a test run |
| `FlowTester` | Class — `@MainActor` runner: model + `@ViewBuilder` + steps → run |

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

- **Branches**: `<type>/<issue-number>-<slug>` (e.g., `feature/32-flow-tester`, `fix/15-sendable-conformance`)
- **Quality gates**: `swift-format .` + `swift build` + `swift test` + `swiftlint` must pass before commit
- **Test-first**: write failing test, implement, verify green
- **No AI attribution** in commit messages

## Documentation

- `docs/API_SPEC.md` — complete type and method reference
- `docs/USER_GUIDE_OVERVIEW.md` — motivation and design philosophy
- `docs/USER_GUIDE_QUICK_START.md` — installation and first test
- `docs/USER_GUIDE_AI_GUIDE.md` — AI agent integration guide
- `docs/USER_GUIDE_GIT_SNAPSHOTS.md` — snapshot storage strategies
- `docs/adr/` — architecture decision records
