# Integrating SwiftUIFlowTesting with AI-Assisted Development

This guide is for **consumers of the SwiftUIFlowTesting library** who use Claude Code or
other AI coding agents in their SwiftUI projects. It provides a CLAUDE.md-style policy
you can adapt for your own app's repository.

---

## Overview

SwiftUIFlowTesting replaces XCUITest for day-to-day UI flow validation. When using AI agents
to implement features, fix bugs, or add tests, configure them to prefer SwiftUIFlowTesting
over XCUITest for all routine UI coverage.

## Recommended CLAUDE.md Policy

Add the following sections to your app's `CLAUDE.md` to guide AI agents:

---

### UI Testing Policy

- **Day-to-day**: Use SwiftUIFlowTesting + SnapshotTesting for all UI flow validation.
- **Do not** rely on XCTest/XCUITest for testing SwiftUI view behavior.
- Reserve XCUITest for a small, curated e2e suite (system-level concerns only).

### View Models as Source of Truth

Every significant screen or flow must be driven by a model type with explicit intent methods:

```swift
Button("Proceed") {
    model.proceedToNextStep()
}
```

Tests call these same methods directly rather than simulating UI events.

### Flow Tests with SwiftUIFlowTesting

For interaction flows, use `FlowTester` to drive flows entirely in-process:

```swift
import Testing
import SwiftUI
import SnapshotTesting
import SwiftUIFlowTesting
@testable import MyApp

@Suite("Checkout Flow")
@MainActor
struct CheckoutFlowTests {
    @Test func happyPath() async throws {
        let model = CheckoutModel(cart: .fixtureMultipleItems)

        let tester = FlowTester(model: model) { model in
            CheckoutView(model: model)
        }

        tester
            .step("cart") { _ in }
            .step("payment") { model in
                model.proceedToPayment()
            } assert: { model in
                #expect(model.screen == .payment)
            }
            .step("confirmation") { model in
                model.confirmOrder()
            } assert: { model in
                #expect(model.screen == .confirmation)
            }
            .run { name, view in
                assertSnapshot(
                    of: view,
                    as: .image(layout: .device(config: .iPhoneX)),
                    named: name
                )
            }
    }
}
```

### Behavior Assertions

Alongside snapshots, assert behavior via model state:

```swift
#expect(model.screen == .confirmation)
#expect(model.isSubmitButtonEnabled)
#expect(model.errorMessage == nil)
```

Expose UI state as properties on the model rather than inspecting the view hierarchy.

---

## XCUITest Policy

### When XCUITest is Allowed

Only for a small, curated set of full e2e tests that validate:
- System integration (windows, menus, focus, keyboard shortcuts)
- Critical app startup/shutdown flows
- Behavior that depends on real system integration

### Where These Tests Live

- Separate test target (e.g., `MyAppE2ETests`)
- Dedicated directory (e.g., `Tests/E2E`)
- Run on CI only — not part of the fast local test loop

---

## Instructions for AI Agents

When implementing features, fixing bugs, or adding tests:

1. **Prefer SwiftUIFlowTesting over XCUITest** for all UI flow coverage
2. **Keep tests in-process and deterministic** — no app bundle launch
3. **Only touch e2e tests when explicitly requested**
4. **When in doubt, propose flow tests** with snapshots at each key step
5. **Use Swift Testing** (`@Test`, `@Suite`, `#expect`) — not XCTest assertions

### Test Naming

- Use descriptive names encoding the flow and outcome:
  - `happyPath_checkoutFlow()`
  - `importFile_showsErrorOnInvalidFormat()`
- Group tests by feature/flow in separate files
- Mark test suites `@MainActor` when constructing SwiftUI views

---

## Adding SwiftUIFlowTesting to Your Project

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/metamech/SwiftUIFlowTesting.git", from: "0.1.0"),
    .package(url: "https://github.com/pointfreeco/swift-snapshot-testing.git", from: "1.17.0"),
],
targets: [
    .testTarget(
        name: "MyAppTests",
        dependencies: [
            "MyApp",
            "SwiftUIFlowTesting",
            .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
        ]
    ),
]
```

SwiftUIFlowTesting has zero external dependencies. Your test target brings SnapshotTesting.
