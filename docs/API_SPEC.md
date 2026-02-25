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

| Type | Kind | Sendable | Actor | Generic Parameters | SPI |
|------|------|----------|-------|--------------------|-----|
| `FlowModel` | Protocol | -- | -- | -- | Stable |
| `FlowViewProvider` | Protocol | -- | -- | `associatedtype FlowBody` | Stable |
| `FlowAssertion` | Struct | Yes | -- | `<Model: FlowModel>` | Stable |
| `FlowStep` | Struct | Yes | -- | `<Model: FlowModel>` | Stable |
| `FlowStepResult` | Struct | Yes | -- | -- | Stable |
| `FlowConfiguration` | Struct | Yes | -- | -- | Stable |
| `FlowTester` | Class | No | @MainActor | `<Model: FlowModel, Content: View>` | Stable |
| `SnapshotConfiguration` | Struct | Yes | -- | -- | Stable |
| `SnapshotResult` | Struct | Yes | -- | -- | Stable |
| `SnapshotMode` | Enum | Yes | -- | -- | Stable |

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

**Conforming existing app models:** If your model already satisfies `AnyObject & Observable` from your app target, use `@retroactive` in a test-target extension:

```swift
extension ContentViewModel: @retroactive FlowModel {}
```

---

## FlowViewProvider

```swift
/// An optional protocol for models that provide a default view.
public protocol FlowViewProvider: FlowModel {
    associatedtype FlowBody: View
    @MainActor var flowBody: FlowBody { get }
}
```

When a model conforms to `FlowViewProvider`, `FlowTester` can be initialized without an explicit `@ViewBuilder` closure:

```swift
extension ContentViewModel: FlowViewProvider {
    var flowBody: some View { ContentView(model: self) }
}

// Tests become:
FlowTester(name: "content", model: vm)
    .step("initial") { _ in }
    .run()
```

The convenience initializer wraps `flowBody` in `AnyView`, so `Content` resolves to `AnyView`. The explicit `@ViewBuilder` init remains the primary path.

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
    public let snapshotEnabled: Bool

    public init(
        name: String,
        action: @escaping @MainActor @Sendable (Model) -> Void,
        assertions: [FlowAssertion<Model>] = [],
        snapshotEnabled: Bool = true
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

    /// Result of the built-in snapshot capture; nil when using the closure API.
    public let snapshotResult: SnapshotResult?
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

## SnapshotConfiguration

```swift
/// Configuration for the built-in snapshot engine.
public struct SnapshotConfiguration: Sendable {
    public let scale: CGFloat              // default: 2.0
    public let proposedSize: ProposedSize  // default: 390×844
    public let record: Bool                // default: checks FLOW_RECORD_SNAPSHOTS env var
    public let snapshotDirectory: String?  // override computed __Snapshots__/ path

    public struct ProposedSize: Sendable {
        public let width: CGFloat
        public let height: CGFloat
        public init(width: CGFloat, height: CGFloat)
    }

    public init(
        scale: CGFloat = 2.0,
        proposedSize: ProposedSize = .init(width: 390, height: 844),
        record: Bool = /* checks FLOW_RECORD_SNAPSHOTS env var */,
        snapshotDirectory: String? = nil
    )
}
```

---

## SnapshotResult

```swift
/// The outcome of a single snapshot capture operation.
public struct SnapshotResult: Sendable {
    public enum Status: Sendable {
        case matched
        case newReference(path: String)
        case mismatch(referencePath: String, actualPath: String)
        case skipped
        case unavailable
    }

    public let status: Status
    public let pngData: Data?

    public init(status: Status, pngData: Data? = nil)
}
```

---

## SnapshotMode

```swift
/// Selects the snapshotting strategy for a flow test run.
public enum SnapshotMode: Sendable {
    case builtin(SnapshotConfiguration = .init())
    case custom(@MainActor @Sendable (String, AnyView) -> Void)
    case disabled
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

### Convenience Init (FlowViewProvider)

```swift
extension FlowTester where Content == AnyView {
    public convenience init(
        name: String? = nil,
        model: Model,
        configuration: FlowConfiguration = .init()
    ) where Model: FlowViewProvider
}
```

### Step Building (Stable)

All step methods accept an optional `snapshot: Bool` parameter (defaults to `true`). When `false`, the step still executes its action and assertions but skips snapshot capture, returning a `.skipped` snapshot status.

```swift
    // Named steps
    @discardableResult
    public func step(
        _ name: String,
        snapshot: Bool = true,
        action: @escaping @MainActor @Sendable (Model) -> Void = { _ in },
        assertions: [FlowAssertion<Model>] = []
    ) -> Self

    @discardableResult
    public func step(
        _ name: String,
        snapshot: Bool = true,
        action: @escaping @MainActor @Sendable (Model) -> Void,
        assert: @escaping @MainActor @Sendable (Model) -> Void
    ) -> Self

    // Unnamed steps (auto-named as "step-{index}" or "{testerName}-step-{index}")
    @discardableResult
    public func step(
        snapshot: Bool = true,
        action: @escaping @MainActor @Sendable (Model) -> Void = { _ in },
        assertions: [FlowAssertion<Model>] = []
    ) -> Self

    @discardableResult
    public func step(
        snapshot: Bool = true,
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
    // Built-in snapshotting (default)
    @discardableResult
    public func run(
        snapshotMode: SnapshotMode = .builtin(),
        filePath: String = #filePath,
        function: String = #function
    ) -> [FlowStepResult]

    // Closure-based snapshotting (advanced)
    @discardableResult
    public func run(
        snapshot: @MainActor (String, AnyView) -> Void
    ) -> [FlowStepResult]

    // Built-in async run
    @discardableResult
    public func asyncRun(
        snapshotMode: SnapshotMode = .builtin(),
        filePath: String = #filePath,
        function: String = #function
    ) async -> [FlowStepResult]

    // Built-in matrix run
    @discardableResult
    public func matrixRun(
        configurations: [FlowConfiguration],
        modelFactory: @MainActor @Sendable () -> Model,
        snapshotMode: SnapshotMode = .builtin(),
        filePath: String = #filePath,
        function: String = #function
    ) -> [FlowStepResult]

    // Closure-based matrix run
    @discardableResult
    public func matrixRun(
        configurations: [FlowConfiguration],
        modelFactory: @MainActor @Sendable () -> Model,
        snapshot: @MainActor (String, AnyView) -> Void
    ) -> [FlowStepResult]
```

> **Experimental** — The following are available under `@_spi(Experimental)`:

### Async Steps (Experimental)

```swift
    @_spi(Experimental) @discardableResult
    public func asyncStep(
        _ name: String,
        snapshot: Bool = true,
        action: @escaping @MainActor @Sendable (Model) async -> Void,
        assertions: [FlowAssertion<Model>] = []
    ) -> Self

    @_spi(Experimental) @discardableResult
    public func asyncStep(
        _ name: String,
        snapshot: Bool = true,
        action: @escaping @MainActor @Sendable (Model) async -> Void,
        assert: @escaping @MainActor @Sendable (Model) -> Void
    ) -> Self

    @_spi(Experimental) @discardableResult
    public func asyncRun(
        snapshot: @MainActor (String, AnyView) -> Void
    ) async -> [FlowStepResult]
```

### Composition (Experimental)

```swift
    @_spi(Experimental)
    public var extractedSteps: [FlowStep<Model>] { get }

    @_spi(Experimental) @discardableResult
    public func steps(_ newSteps: [FlowStep<Model>]) -> Self
}
```

### Snapshot Attachment Convenience (Stable)

```swift
extension [FlowStepResult] {
    /// Passes each step's snapshot PNG data to a handler for attachment.
    public func attachSnapshots(using handler: (Data, String) -> Void)
}
```

**Usage with Swift Testing:**

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

---

## File Layout

```
Sources/
  SwiftUIFlowTesting/
    SwiftUIFlowTesting.swift       -- Module-level comment (no public API)
    FlowModel.swift                -- FlowModel protocol
    FlowViewProvider.swift         -- FlowViewProvider protocol
    FlowAssertion.swift            -- FlowAssertion<Model>
    FlowStep.swift                 -- FlowStep<Model>
    FlowStepResult.swift           -- FlowStepResult
    FlowConfiguration.swift        -- FlowConfiguration
    FlowTester.swift               -- FlowTester<Model, Content>
    SnapshotConfiguration.swift    -- SnapshotConfiguration
    SnapshotResult.swift           -- SnapshotResult
    SnapshotMode.swift             -- SnapshotMode
    SnapshotEngine.swift           -- Internal snapshot rendering engine
    FlowTester+Snapshots.swift     -- [FlowStepResult].attachSnapshots
Tests/
  SwiftUIFlowTestingTests/
    TestHelpers.swift               -- MockModel, MockView (test-only)
    FlowStepTests.swift             -- FlowStep construction, assertions
    FlowConfigurationTests.swift
    FlowTesterTests.swift           -- Step building, run execution, results
    FlowViewProviderTests.swift     -- FlowViewProvider convenience init
    SnapshotConfigurationTests.swift -- SnapshotConfiguration defaults, custom values
    SnapshotEngineTests.swift       -- Render, record, match, mismatch
    FlowTesterSnapshotTests.swift   -- Built-in snapshot integration tests
```

---

## Quick Reference Template

### Built-in Snapshots (Default)

```swift
import Testing
import SwiftUIFlowTesting

@Suite @MainActor
struct MyFlowTests {
    @Test func myFlow() {
        let model = MyModel()

        FlowTester(model: model) { m in MyView(model: m) }
            .step("initial") { _ in }
            .step("after-action", action: { $0.doSomething() }, assert: { m in
                #expect(m.state == .expected)
            })
            .run()  // Uses built-in ImageRenderer snapshots
    }
}
```

### Closure API (Advanced)

```swift
import SwiftUI
import Testing
import SwiftUIFlowTesting
// import SnapshotTesting        // only if using snapshots

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

> **Warning:** Putting `#expect` inside a trailing closure (action) runs it **before** snapshot capture. The execution order is: action → render → snapshot → assertions. To assert model state after render, always use the `action:` + `assert:` form:
>
> ```swift
> // WRONG — #expect runs before render/snapshot:
> .step("payment") { model in
>     model.proceedToPayment()
>     #expect(model.screen == .payment)
> }
>
> // CORRECT — #expect runs after render + snapshot:
> .step("payment", action: { $0.proceedToPayment() }, assert: { model in
>     #expect(model.screen == .payment)
> })
> ```

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
| Flow test with built-in snapshots | `Testing`, `SwiftUIFlowTesting` |
| Flow test without snapshots | `Testing`, `SwiftUIFlowTesting` (use `.run(snapshotMode: .disabled)`) |
| Flow test with external snapshots | `Testing`, `SwiftUI`, `SnapshotTesting`, `SwiftUIFlowTesting` |
| Accessing app internals | Add `@testable import MyApp` |
| Using experimental APIs | Add `@_spi(Experimental)` to the import |
