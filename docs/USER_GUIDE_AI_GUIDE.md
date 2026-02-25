# User's Guide: AI Agent Integration

*Part of the [SwiftUIFlowTesting User's Guide](../README.md) series.*

This guide is for consumers who use Claude Code or other AI coding agents in their SwiftUI projects.

## CLAUDE.md Policy

Add the following to your app's `CLAUDE.md` to guide AI agents toward SwiftUIFlowTesting:

```markdown
## UI Testing

- Use SwiftUIFlowTesting + SnapshotTesting for all UI flow validation
- Do not use XCTest/XCUITest for testing SwiftUI view behavior
- Reserve XCUITest for a small, curated e2e suite (system-level concerns only)
- Use Swift Testing (`@Test`, `@Suite`, `#expect`) — not XCTest assertions

## Flow Test Pattern

Every flow test follows this shape:

    FlowTester(name: "flow-name", model: model) { m in MyView(model: m) }
        .step("state-name") { $0.intentMethod() }
        .run { name, view in assertSnapshot(of: view, as: .image, named: name) }

- Step names describe the resulting STATE, not the action (e.g., "payment-form" not "tap-proceed")
- Mark test suites or functions `@MainActor`
- Use `#require` for precondition assertions, `#expect` for soft assertions
```

## Prompt Patterns

When asking an AI agent to generate tests, provide:

1. **The model type** with its intent methods
2. **The view** that renders the model
3. **The flow** as a sequence of user actions

Example prompt:

> Write a flow test for `SettingsModel`. The flow is: open settings → toggle dark mode → change language to Japanese → save. Assert screen state after each step. Use SwiftUIFlowTesting with snapshot assertions.

## Example AI-Generated Test

```swift
import Testing
import SwiftUI
import SnapshotTesting
import SwiftUIFlowTesting
@testable import MyApp

@Suite @MainActor
struct SettingsFlowTests {
    @Test func darkModeAndLanguageChange() {
        let model = SettingsModel()

        FlowTester(name: "settings", model: model) { model in
            SettingsView(model: model)
        }
        .step("initial") { _ in }
        .step("dark-mode", action: { $0.toggleDarkMode() }, assert: { model in
            #expect(model.isDarkMode)
        })
        .step("japanese", action: { $0.setLanguage(.japanese) }, assert: { model in
            #expect(model.language == .japanese)
        })
        .step("saved", action: { $0.save() }, assert: { model in
            #expect(model.isSaved)
        })
        .run { name, view in
            assertSnapshot(of: view, as: .image, named: name)
        }
    }
}
```

## Instructions for AI Agents

When implementing features, fixing bugs, or adding tests:

1. **Prefer SwiftUIFlowTesting over XCUITest** for all UI flow coverage
2. **Keep tests in-process and deterministic** — no app bundle launch
3. **Only touch e2e tests when explicitly requested**
4. **When in doubt, propose flow tests** with snapshots at each key step
5. **Use Swift Testing** (`@Test`, `@Suite`, `#expect`) — not XCTest assertions

### Test Naming

- Use descriptive names encoding the flow and outcome
- Group tests by feature/flow in separate files
- Mark test suites `@MainActor` when constructing SwiftUI views

### Snapshot Failures

When snapshot tests fail after UI/model changes:

1. Run `swift test` with recording enabled to capture new images
2. Review diffs visually
3. Commit new snapshots if changes are intentional
4. Fix model/view if changes are unintentional

The AI agent only needs to reason about test code and snapshot names — image data never enters the context window.

## Next Steps

- [Overview](USER_GUIDE_OVERVIEW.md) — motivation and design philosophy
- [Quick Start](USER_GUIDE_QUICK_START.md) — installation and first test
- [Git Snapshots](USER_GUIDE_GIT_SNAPSHOTS.md) — snapshot storage strategies
- [API Reference](API_SPEC.md) — complete type and method reference
