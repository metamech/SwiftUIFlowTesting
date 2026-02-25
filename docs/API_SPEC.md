# SwiftUIFlowTesting — API Reference

**Swift 6.2 | Strict Concurrency | SwiftUI + Foundation only**

For design rationale, see the [Architecture Decision Records](adr/).

---

## Package Requirements

```swift
// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "SwiftUIFlowTesting",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
        .tvOS(.v17),
        .watchOS(.v10),
        .visionOS(.v1),
    ],
    products: [
        .library(name: "SwiftUIFlowTesting", targets: ["SwiftUIFlowTesting"]),
    ],
    targets: [
        .target(name: "SwiftUIFlowTesting"),
        .testTarget(
            name: "SwiftUIFlowTestingTests",
            dependencies: ["SwiftUIFlowTesting"]
        ),
    ]
)
```

---

## Type Summary

| Type | Kind | Sendable | Actor | Generic Parameters |
|------|------|----------|-------|--------------------|
| `FlowModel` | Protocol | -- | -- | -- |
| `FlowAssertion` | Struct | Yes | -- | `<Model: FlowModel>` |
| `FlowStep` | Struct | Yes | -- | `<Model: FlowModel>` |
| `FlowStepResult` | Struct | Yes | -- | -- |
| `FlowConfiguration` | Struct | Yes | -- | -- |
| `FlowTester` | Class | No | @MainActor | `<Model: FlowModel, Content: View>` |

---

## FlowModel

```swift
/// A model that drives a SwiftUI screen or flow under test.
///
/// Conforming types must be `Observable` reference types whose properties
/// are tracked by the Observation framework (`@Observable` macro).
public protocol FlowModel: AnyObject, Observable {}
```

**Usage:**

```swift
@Observable
final class CheckoutModel: FlowModel {
    var screen: Screen = .cart
    func proceedToPayment() { screen = .payment }
}
```

---

## FlowAssertion

```swift
/// A single named assertion to run against a model after a flow step.
public struct FlowAssertion<Model: FlowModel>: Sendable {
    public let label: String
    public let body: @MainActor @Sendable (Model) -> Void

    public init(
        _ label: String = "",
        body: @escaping @MainActor @Sendable (Model) -> Void
    )
}
```

**Usage:**

```swift
FlowAssertion("screen is payment") { model in
    #expect(model.screen == .payment)
}
```

---

## FlowStep

```swift
/// One step in a UI flow test.
public struct FlowStep<Model: FlowModel>: Sendable {
    public let name: String
    public let action: @MainActor @Sendable (Model) -> Void
    public let assertions: [FlowAssertion<Model>]

    public init(
        name: String,
        action: @escaping @MainActor @Sendable (Model) -> Void,
        assertions: [FlowAssertion<Model>] = []
    )
}
```

> **Experimental** — The following are available under `@_spi(Experimental)`:

```swift
extension FlowStep {
    /// An optional async action used by `asyncRun()`.
    @_spi(Experimental)
    public let asyncAction: (@MainActor @Sendable (Model) async -> Void)?

    @_spi(Experimental)
    public init(
        name: String,
        action: @escaping @MainActor @Sendable (Model) -> Void,
        asyncAction: (@MainActor @Sendable (Model) async -> Void)?,
        assertions: [FlowAssertion<Model>] = []
    )
}
```

---

## FlowStepResult

```swift
/// The result of executing a single flow step.
public struct FlowStepResult: Sendable {
    public let stepName: String
    public let resolvedName: String
    public let index: Int
}
```

> **Experimental** — The following properties are available under `@_spi(Experimental)`:

```swift
extension FlowStepResult {
    /// Wall-clock duration of step execution.
    @_spi(Experimental) public let duration: Duration

    /// Number of assertions executed in this step.
    @_spi(Experimental) public let assertionCount: Int

    /// Configuration label from matrix runs; nil otherwise.
    @_spi(Experimental) public let configurationLabel: String?
}
```

---

## FlowConfiguration

```swift
/// Configuration for a flow test run.
public struct FlowConfiguration: Sendable {
    public let label: String
    public let environmentPatch: @MainActor @Sendable (inout EnvironmentValues) -> Void

    public init(
        label: String = "",
        environmentPatch: @escaping @MainActor @Sendable (inout EnvironmentValues) -> Void = { _ in }
    )
}
```

**Usage:**

```swift
let config = FlowConfiguration(label: "dark") { env in
    env.colorScheme = .dark
    env.locale = Locale(identifier: "ja_JP")
}
```

---

## FlowTester

```swift
/// The central flow test runner.
@MainActor
public final class FlowTester<Model: FlowModel, Content: View> {
    public let name: String?
    public let model: Model
    public let configuration: FlowConfiguration
```

### Initialization

```swift
    public init(
        name: String? = nil,
        model: Model,
        configuration: FlowConfiguration = .init(),
        @ViewBuilder viewBuilder: @escaping @MainActor @Sendable (Model) -> Content
    )
```

### Step Building (Stable)

```swift
    // Named steps
    @discardableResult
    public func step(
        _ name: String,
        action: @escaping @MainActor @Sendable (Model) -> Void = { _ in },
        assertions: [FlowAssertion<Model>] = []
    ) -> Self

    @discardableResult
    public func step(
        _ name: String,
        action: @escaping @MainActor @Sendable (Model) -> Void,
        assert: @escaping @MainActor @Sendable (Model) -> Void
    ) -> Self

    // Unnamed steps (auto-named as "step-{index}" or "{testerName}-step-{index}")
    @discardableResult
    public func step(
        action: @escaping @MainActor @Sendable (Model) -> Void = { _ in },
        assertions: [FlowAssertion<Model>] = []
    ) -> Self

    @discardableResult
    public func step(
        action: @escaping @MainActor @Sendable (Model) -> Void,
        assert: @escaping @MainActor @Sendable (Model) -> Void
    ) -> Self
```

### Lifecycle Hooks (Stable)

```swift
    @discardableResult
    public func beforeEachStep(
        _ hook: @escaping @MainActor @Sendable (String, Int, Model) -> Void
    ) -> Self

    @discardableResult
    public func afterEachStep(
        _ hook: @escaping @MainActor @Sendable (String, Int, Model) -> Void
    ) -> Self
```

### Introspection (Stable)

```swift
    public var stepCount: Int { get }
    public var stepNames: [String] { get }
```

### Execution (Stable)

```swift
    @discardableResult
    public func run(
        snapshot: @MainActor (String, AnyView) -> Void
    ) -> [FlowStepResult]
```

> **Experimental** — The following are available under `@_spi(Experimental)`:

### Async Steps (Experimental)

```swift
    @_spi(Experimental) @discardableResult
    public func asyncStep(
        _ name: String,
        action: @escaping @MainActor @Sendable (Model) async -> Void,
        assertions: [FlowAssertion<Model>] = []
    ) -> Self

    @_spi(Experimental) @discardableResult
    public func asyncStep(
        _ name: String,
        action: @escaping @MainActor @Sendable (Model) async -> Void,
        assert: @escaping @MainActor @Sendable (Model) -> Void
    ) -> Self

    @_spi(Experimental) @discardableResult
    public func asyncRun(
        snapshot: @MainActor (String, AnyView) -> Void
    ) async -> [FlowStepResult]
```

### Matrix Runs (Experimental)

```swift
    @_spi(Experimental) @discardableResult
    public func matrixRun(
        configurations: [FlowConfiguration],
        modelFactory: @MainActor @Sendable () -> Model,
        snapshot: @MainActor (String, AnyView) -> Void
    ) -> [FlowStepResult]
```

### Composition (Experimental)

```swift
    @_spi(Experimental)
    public var extractedSteps: [FlowStep<Model>] { get }

    @_spi(Experimental) @discardableResult
    public func steps(_ newSteps: [FlowStep<Model>]) -> Self
}
```

---

## File Layout

```
Sources/
  SwiftUIFlowTesting/
    SwiftUIFlowTesting.swift   -- Module-level comment (no public API)
    FlowModel.swift            -- FlowModel protocol
    FlowAssertion.swift        -- FlowAssertion<Model>
    FlowStep.swift             -- FlowStep<Model>
    FlowStepResult.swift       -- FlowStepResult
    FlowConfiguration.swift    -- FlowConfiguration
    FlowTester.swift           -- FlowTester<Model, Content>
Tests/
  SwiftUIFlowTestingTests/
    TestHelpers.swift           -- MockModel, MockView (test-only)
    FlowStepTests.swift         -- FlowStep construction, assertions
    FlowConfigurationTests.swift
    FlowTesterTests.swift       -- Step building, run execution, results
```

---

## Quick Reference Template

Minimal copy-paste-ready flow test:

```swift
import SwiftUI
import Testing
import SwiftUIFlowTesting
// import SnapshotTesting        // only if using snapshots
// @testable import MyApp        // only if accessing internal types

@Suite @MainActor
struct MyFlowTests {
    @Test func myFlow() {
        let model = MyModel()

        FlowTester(model: model) { m in MyView(model: m) }
            .step("initial") { _ in }
            .step("after-action", action: { $0.doSomething() }, assert: { m in
                #expect(m.state == .expected)
            })
            .run { name, view in
                // Snapshot hook — consumers provide their own strategy:
                // assertSnapshot(of: view, as: .image, named: name)
            }
    }
}
```

---

## Common Pitfalls

### Overload Disambiguation

`FlowTester` has two `step` overloads:

1. **Action-only**: `step(_ name:, action:, assertions:)` — `action` defaults to no-op, `assertions` defaults to empty.
2. **Action + single assert**: `step(_ name:, action:, assert:)` — `action` has **no default** to avoid ambiguity with overload 1.

A bare trailing closure always resolves to the action-only overload:

```swift
// This is an ACTION closure, not an assertion:
.step("idle") { _ in }

// To use the assert: convenience, BOTH closures must be provided:
.step("advance", action: { $0.doSomething() }, assert: { m in
    #expect(m.state == .expected)
})
```

### @MainActor Required on All Tests

`FlowTester` is `@MainActor`-isolated. Every test function or suite that uses `FlowTester` **must** be annotated `@MainActor`:

```swift
// Correct:
@Suite @MainActor struct MyTests { ... }

// WRONG — will produce concurrency errors:
@Test func myTest() { ... }
```

### Assertion Failure Behavior

Assertions run via `#expect` are **soft failures** — a failing assertion records the failure but does not halt the flow. Use `#require` if a step's assertion is a precondition for subsequent steps:

```swift
.step("login", action: { $0.login() }, assert: { m in
    try #require(m.isLoggedIn)
})
```

When using `#require`, the test function must be marked `throws`.

### Step Naming Conventions

Step names become snapshot identifiers. Use kebab-case, lowercase, descriptive of **state** not action:

```swift
// Good:
.step("cart-empty") { _ in }
.step("payment-form") { $0.proceedToPayment() }

// Avoid:
.step("tap proceed button") { ... }
```

### Required Imports

| Scenario | Imports |
|----------|---------|
| Flow test without snapshots | `Testing`, `SwiftUIFlowTesting` |
| Flow test with snapshots | `Testing`, `SwiftUI`, `SnapshotTesting`, `SwiftUIFlowTesting` |
| Accessing app internals | Add `@testable import MyApp` |
| Using experimental APIs | Add `@_spi(Experimental)` to the import |
