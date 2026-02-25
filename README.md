# SwiftUIFlowTesting

In-process pseudo-e2e testing for SwiftUI apps. Drive UI flows via model intent methods, render views, and capture snapshots — all without XCUITest.

![Swift 6.2](https://img.shields.io/badge/Swift-6.2-orange) ![Platforms](https://img.shields.io/badge/Platforms-iOS%2017%20%7C%20macOS%2014%20%7C%20tvOS%2017%20%7C%20watchOS%2010%20%7C%20visionOS%201-blue) ![License: MIT](https://img.shields.io/badge/License-MIT-green)

## Motivation

XCUITest is slow, serialized, and locks your machine. Most SwiftUI UI tests don't need a running app — they need to verify that model state mutations produce correct views. SwiftUIFlowTesting lets you test multi-step UI flows entirely in-process, with snapshot assertions at each step.

## Quick Example

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
        .step("payment") { $0.proceedToPayment() }
        .step("confirmation") { $0.confirmOrder() }
        .run { name, view in
            assertSnapshot(of: view, as: .image, named: name)
        }
    }
}
```

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
            .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
        ]
    ),
]
```

SwiftUIFlowTesting has **zero external dependencies**. Your test target brings [SnapshotTesting](https://github.com/pointfreeco/swift-snapshot-testing).

## Documentation

- [Overview](docs/USER_GUIDE_OVERVIEW.md) — What the framework does and why
- [Quick Start](docs/USER_GUIDE_QUICK_START.md) — Installation and first test
- [AI Guide](docs/USER_GUIDE_AI_GUIDE.md) — Using with Claude Code and other AI agents
- [Git Snapshots](docs/USER_GUIDE_GIT_SNAPSHOTS.md) — Snapshot storage strategies
- [API Reference](docs/API_SPEC.md) — Complete type and method reference

## Experimental Features

Some APIs ship under `@_spi(Experimental)` and may change in future releases:

- `asyncStep` / `asyncRun` — async step actions
- `matrixRun` — run flows across multiple configurations
- `extractedSteps` / `steps(_:)` — step composition
- `FlowStepResult.duration` / `.assertionCount` / `.configurationLabel`
- `FlowStep.asyncAction`

To use experimental APIs:

```swift
@_spi(Experimental) import SwiftUIFlowTesting
```

## License

MIT. See [LICENSE](LICENSE).
