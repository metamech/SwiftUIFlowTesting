# User's Guide: Quick Start

*Part of the [SwiftUIFlowTesting User's Guide](../README.md) series.*

## Installation

Add SwiftUIFlowTesting and SnapshotTesting to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/metamech/SwiftUIFlowTesting.git", from: "1.0.0"),
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
import SwiftUI
import SnapshotTesting
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
        .run { name, view in
            assertSnapshot(of: view, as: .image, named: name)
        }
    }
}
```

## Run Tests

```bash
swift test
```

The first run records reference snapshots. Subsequent runs compare against them.

## Key Concepts

- **`FlowTester`** — the runner. Give it a model, a view builder, and chain steps.
- **`step(_:action:)`** — mutates the model to simulate a user interaction.
- **`run(snapshot:)`** — executes all steps. For each step: action → render → snapshot → assertions.
- **`@MainActor`** — required on all tests using `FlowTester` (SwiftUI views must be constructed on the main actor).

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

## Next Steps

- [Overview](USER_GUIDE_OVERVIEW.md) — motivation and design philosophy
- [AI Guide](USER_GUIDE_AI_GUIDE.md) — configure AI agents to generate flow tests
- [Git Snapshots](USER_GUIDE_GIT_SNAPSHOTS.md) — snapshot storage strategies
- [API Reference](API_SPEC.md) — complete type and method reference
