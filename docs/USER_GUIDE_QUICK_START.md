# User's Guide: Quick Start

*Part of the [SwiftUIFlowTesting User's Guide](../README.md) series.*

## Installation

Add SwiftUIFlowTesting to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/metamech/SwiftUIFlowTesting.git", from: "1.0.0"),
],
targets: [
    .testTarget(
        name: "MyAppTests",
        dependencies: [
            "MyApp",
            "SwiftUIFlowTesting",
        ]
    ),
]
```

No other dependencies are needed — snapshot rendering is built in.

## Make Your Model Conformant

Your model must conform to `FlowModel`, which requires `AnyObject & Observable`. The `@Observable` macro handles both:

```swift
import SwiftUI
import SwiftUIFlowTesting

@Observable
final class CheckoutModel: FlowModel {
    var screen: Screen = .cart
    var isSubmitEnabled = true

    func proceedToPayment() { screen = .payment }
    func confirmOrder() { screen = .confirmation }
}
```

## Write Your First Flow Test

```swift
import Testing
import SwiftUIFlowTesting
@testable import MyApp

@Suite @MainActor
struct CheckoutFlowTests {
    @Test func happyPath() {
        let model = CheckoutModel(cart: .fixture)

        FlowTester(name: "checkout", model: model) { model in
            CheckoutView(model: model)
        }
        .step("cart") { _ in }
        .step("payment", action: { $0.proceedToPayment() }, assert: { model in
            #expect(model.screen == .payment)
        })
        .step("confirmation", action: { $0.confirmOrder() }, assert: { model in
            #expect(model.screen == .confirmation)
        })
        .run()
    }
}
```

Calling `.run()` with no arguments uses the built-in snapshot engine. Each step's view is rendered to PNG via `ImageRenderer` and saved to `__Snapshots__/` alongside the test file.

## Run Tests

```bash
swift test
```

The first run records reference snapshots. Subsequent runs compare against them. Mismatches are saved as `.fail.png` for visual inspection.

## Key Concepts

- **`FlowTester`** — the runner. Give it a model, a view builder, and chain steps.
- **`step(_:action:)`** — mutates the model to simulate a user interaction.
- **`.run()`** — executes all steps. For each step: action → render → snapshot comparison → assertions.
- **`@MainActor`** — required on all tests using `FlowTester` (SwiftUI views must be constructed on the main actor).

## Snapshot Configuration

Customize the rendering scale, view size, or snapshot directory:

```swift
let snapConfig = SnapshotConfiguration(
    scale: 3.0,
    proposedSize: .init(width: 393, height: 852)
)

FlowTester(model: model) { m in MyView(model: m) }
    .step("screen") { _ in }
    .run(snapshotMode: .builtin(snapConfig))
```

## Recording Mode

To re-record all reference snapshots (e.g., after intentional UI changes):

```bash
FLOW_RECORD_SNAPSHOTS=1 swift test
```

Or per-test:

```swift
let config = SnapshotConfiguration(record: true)
tester.run(snapshotMode: .builtin(config))
```

## Disabling Snapshots

To run assertions only without capturing images:

```swift
tester.run(snapshotMode: .disabled)
```

## Environment Overrides

Test dark mode, locales, or dynamic type by passing a `FlowConfiguration`:

```swift
let config = FlowConfiguration { env in
    env.colorScheme = .dark
    env.locale = Locale(identifier: "ja_JP")
}

FlowTester(model: model, configuration: config) { model in
    CheckoutView(model: model)
}
```

## Attaching Snapshots to Test Results

Bridge snapshot data into Swift Testing attachments:

```swift
import Testing
import SwiftUIFlowTesting

@Test @MainActor func myFlow() {
    FlowTester(model: model) { m in MyView(model: m) }
        .step("cart") { $0.goToCart() }
        .run()
        .attachSnapshots { data, name in
            Attachment.record(data, named: name)
        }
}
```

## Advanced: External Snapshot Libraries

If you prefer [swift-snapshot-testing](https://github.com/pointfreeco/swift-snapshot-testing) or another library, use the closure-based `run(snapshot:)` API instead:

```swift
import SnapshotTesting

FlowTester(model: model) { m in MyView(model: m) }
    .step("cart") { _ in }
    .run { name, view in
        assertSnapshot(of: view, as: .image, named: name)
    }
```

Or use `SnapshotMode.custom` for the same effect:

```swift
FlowTester(model: model) { m in MyView(model: m) }
    .step("cart") { _ in }
    .run(snapshotMode: .custom { name, view in
        assertSnapshot(of: view, as: .image, named: name)
    })
```

This path gives you access to SnapshotTesting's full feature set (perceptual diff, multiple strategies, etc.) but requires adding it as a dependency.

## Next Steps

- [Overview](USER_GUIDE_OVERVIEW.md) — motivation and design philosophy
- [AI Guide](USER_GUIDE_AI_GUIDE.md) — configure AI agents to generate flow tests
- [Git Snapshots](USER_GUIDE_GIT_SNAPSHOTS.md) — snapshot storage strategies
- [API Reference](API_SPEC.md) — complete type and method reference
