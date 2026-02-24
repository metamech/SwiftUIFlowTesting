# SwiftUIFlowTesting -- API Specification

**Swift 6.2 | Strict Concurrency | SwiftUI + Foundation only**

---

## Design Decisions

### 1. FlowModel: AnyObject + Observable

`FlowModel` requires `AnyObject & Observable`. Rationale:

- Swift 6.2 targets iOS 17+ / macOS 14+ where `@Observable` (Observation framework) is
  the standard. Requiring `Observable` means views using `@State` / `@Bindable` work
  correctly when the tester renders them, and property changes propagate without
  `ObservableObject` / `@Published` boilerplate.
- `AnyObject` is implied by `Observable` but stated explicitly for clarity: models are
  reference types mutated in-place by step actions.
- Apps targeting older OS versions with `ObservableObject` can add a trivial
  retroactive `Observable` conformance or use the legacy type alias (not provided by
  this library).

### 2. FlowStep.action: synchronous, not async throws

Actions are synchronous `@MainActor (Model) -> Void`. Rationale:

- Flow testing exercises the model's intent methods (`model.proceedToPayment()`), which
  are synchronous state mutations. The model owns async work internally; tests should
  not need to await it during the step action.
- If a consumer needs async setup between steps, they do so before calling the next
  step or use `run(setup:)` with an async preamble. Keeping the core synchronous avoids
  forcing `async` on every test and keeps the runner simple.
- If future demand warrants it, an `asyncStep` variant can be added without breaking
  the synchronous API.

### 3. Assertions: array of closures

Each step carries an array `[Assertion]` rather than a single optional closure.
Rationale:

- Multiple assertions per step are common (check screen state, check button enabled,
  check error nil). An array lets each assertion have its own label for diagnostics.
- A single closure still works: pass one element in the array, or use the convenience
  overload that takes a single closure.

### 4. Sendable requirements

Under Swift 6.2 strict concurrency:

- `FlowStep` is `Sendable`. Its closures are `@MainActor @Sendable`.
- `FlowConfiguration` is `Sendable`. Its `environmentPatch` closure is
  `@MainActor @Sendable`.
- `FlowTester` is `@MainActor` isolated. It is not `Sendable` and must not cross
  actor boundaries. This is correct because SwiftUI view construction and model
  mutation must happen on `@MainActor`.
- `FlowModel` inherits `Sendable` from `Observable` in practice, but we do not add
  an explicit `Sendable` requirement to the protocol to avoid over-constraining models
  that hold non-Sendable internal state.

### 5. FlowConfiguration.environmentPatch and @MainActor

`EnvironmentValues` manipulation requires `@MainActor` because `EnvironmentValues`
is a SwiftUI type used during view construction. The closure is
`@MainActor @Sendable (inout EnvironmentValues) -> Void`.

### 6. AnyView type erasure in run(snapshot:)

The snapshot closure receives `some View` via a generic helper rather than `AnyView`.
Specifically, the runner wraps the factory output in an internal
`EnvironmentPatchView<Content>` and passes that concrete type erased through
`AnyView` only at the boundary where it enters the snapshot closure. This is
acceptable because:

- The snapshot closure is provided by the consumer (e.g., wrapping
  `assertSnapshot`), which already accepts `AnyView` or `any View`.
- `AnyView` cost is negligible in a test-only context (no diffing, no animation).
- Avoiding `AnyView` entirely would require the snapshot closure to be generic,
  which makes the `run` signature unwieldy and breaks the builder chain.

### 7. Builder pattern vs. result builder

The builder pattern (methods returning `Self`) is retained. Rationale:

- Steps are ordered and the builder pattern naturally expresses sequential chains.
- A result builder (`@FlowStepBuilder`) adds complexity (custom DSL, control flow
  limitations) for minimal ergonomic gain when steps are linear.
- The builder pattern composes well with trailing-closure syntax for `action:` and
  `assert:`.

### 8. Platform minimums

| Platform | Minimum  | Reason                                   |
|----------|----------|------------------------------------------|
| iOS      | 17.0     | `@Observable` (Observation framework)    |
| macOS    | 14.0     | `@Observable` (Observation framework)    |
| tvOS     | 17.0     | `@Observable` (Observation framework)    |
| watchOS  | 10.0     | `@Observable` (Observation framework)    |
| visionOS | 1.0      | Ships with Observation framework         |

### 9. API improvements over pseudocode

- Eliminated `FlowViewFactory` protocol and `ClosureFlowViewFactory` wrapper. The
  tester now takes a `@MainActor @Sendable (Model) -> some View` closure directly.
  This removes an entire protocol + struct that existed only to wrap a closure.
- Added `FlowAssertion` as a named struct with a label, improving diagnostics.
- `FlowConfiguration` renamed `environmentValues` to `environmentPatch` for clarity
  (it is a mutation closure, not a value).
- `FlowConfiguration` dropped `recordSnapshots` (that is a SnapshotTesting concern;
  the consumer controls it via the snapshot closure or SnapshotTesting's own
  `isRecording` flag).
- Added `stepCount` and `stepNames` read-only properties for introspection.
- `run` returns `[FlowStepResult]` so the caller can inspect timing or per-step
  metadata after execution.

---

## Package.swift Requirements

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

## Public API

### FlowModel

```swift
import SwiftUI

/// A model that drives a SwiftUI screen or flow under test.
///
/// Conforming types must be `Observable` reference types whose properties
/// are tracked by the Observation framework (`@Observable` macro). The
/// tester mutates the model in-place via intent methods, then renders
/// the corresponding view to capture snapshots and run assertions.
///
/// Example:
/// ```swift
/// @Observable
/// final class CheckoutModel: FlowModel {
///     var screen: Screen = .cart
///     var isSubmitEnabled = true
///
///     func proceedToPayment() { screen = .payment }
///     func confirmOrder() { screen = .confirmation }
/// }
/// ```
public protocol FlowModel: AnyObject, Observable {}
```

### FlowAssertion

```swift
/// A single named assertion to run against a model after a flow step.
///
/// The `label` aids diagnostics when an assertion fails. The `body` closure
/// runs on `@MainActor` and receives the current model state.
///
/// Example:
/// ```swift
/// FlowAssertion("screen is payment") { model in
///     #expect(model.screen == .payment)
/// }
/// ```
public struct FlowAssertion<Model: FlowModel>: Sendable {
    /// A human-readable label describing what this assertion checks.
    public let label: String

    /// The assertion body. Runs on `@MainActor` after the step action
    /// and snapshot capture.
    public let body: @MainActor @Sendable (Model) -> Void

    /// Creates a named assertion.
    ///
    /// - Parameters:
    ///   - label: A description of what this assertion verifies.
    ///   - body: A closure that performs the assertion against the model.
    public init(
        _ label: String = "",
        body: @escaping @MainActor @Sendable (Model) -> Void
    ) {
        self.label = label
        self.body = body
    }
}
```

### FlowStep

```swift
/// One step in a UI flow test.
///
/// A step has a name (used as the snapshot identifier), an action that
/// mutates the model to simulate a user interaction, and zero or more
/// assertions that verify the resulting model state.
///
/// Steps are built via `FlowTester.step(_:action:assertions:)` rather
/// than constructed directly.
public struct FlowStep<Model: FlowModel>: Sendable {
    /// The step name, used as the snapshot identifier.
    public let name: String

    /// The action to perform on the model. Simulates a user interaction
    /// by calling the model's intent methods.
    public let action: @MainActor @Sendable (Model) -> Void

    /// Assertions to run after the action and snapshot capture.
    public let assertions: [FlowAssertion<Model>]

    /// Creates a flow step.
    ///
    /// - Parameters:
    ///   - name: Identifier for the step (used in snapshot file names).
    ///   - action: Closure that mutates the model to simulate interaction.
    ///   - assertions: Zero or more assertions to verify model state.
    public init(
        name: String,
        action: @escaping @MainActor @Sendable (Model) -> Void,
        assertions: [FlowAssertion<Model>] = []
    ) {
        self.name = name
        self.action = action
        self.assertions = assertions
    }
}
```

### FlowStepResult

```swift
/// The result of executing a single flow step.
///
/// Returned by `FlowTester.run(snapshot:)` for optional post-run
/// inspection (e.g., logging step names in CI output).
public struct FlowStepResult: Sendable {
    /// The name of the step that was executed.
    public let stepName: String

    /// The index of this step in the flow (zero-based).
    public let index: Int
}
```

### FlowConfiguration

```swift
/// Configuration for a flow test run.
///
/// Controls how the tester prepares the SwiftUI environment before
/// rendering each step's view. Consumers use this to inject color
/// scheme, locale, dynamic type size, or other environment overrides.
///
/// Example:
/// ```swift
/// let config = FlowConfiguration { env in
///     env.colorScheme = .dark
///     env.locale = Locale(identifier: "ja_JP")
/// }
/// ```
public struct FlowConfiguration: Sendable {
    /// A closure that patches `EnvironmentValues` before each view render.
    /// Runs on `@MainActor` because `EnvironmentValues` is a SwiftUI type.
    public let environmentPatch: @MainActor @Sendable (inout EnvironmentValues) -> Void

    /// Creates a flow configuration.
    ///
    /// - Parameter environmentPatch: A closure to customize the SwiftUI
    ///   environment for rendered views. Defaults to no-op.
    public init(
        environmentPatch: @escaping @MainActor @Sendable (inout EnvironmentValues) -> Void = { _ in }
    ) {
        self.environmentPatch = environmentPatch
    }
}
```

### FlowTester

```swift
/// The central flow test runner.
///
/// `FlowTester` drives a UI flow by owning a model, building steps via a
/// chainable builder API, then executing the flow with `run(snapshot:)`.
/// For each step it: (1) runs the action, (2) renders the view,
/// (3) calls the snapshot closure, (4) runs assertions.
///
/// `FlowTester` is `@MainActor`-isolated. All construction, step building,
/// and execution must happen on the main actor. This is natural in test
/// code annotated `@MainActor` or `@Suite(.serialized)`.
///
/// Example:
/// ```swift
/// @Test @MainActor
/// func checkoutHappyPath() {
///     let model = CheckoutModel(cart: .fixture)
///
///     FlowTester(model: model) { model in
///         CheckoutView(model: model)
///     }
///     .step("cart") { _ in }
///     .step("payment") { $0.proceedToPayment() }
///     .step("confirmation") { $0.confirmOrder() }
///     .run { name, view in
///         assertSnapshot(of: view, as: .image, named: name)
///     }
/// }
/// ```
@MainActor
public final class FlowTester<Model: FlowModel, Content: View> {
    /// The model instance being driven through the flow.
    public let model: Model

    /// The configuration controlling environment patches.
    public let configuration: FlowConfiguration

    private let viewBuilder: @MainActor @Sendable (Model) -> Content
    private var steps: [FlowStep<Model>] = []

    // MARK: - Initialization

    /// Creates a flow tester.
    ///
    /// - Parameters:
    ///   - model: The model instance to drive through the flow.
    ///   - configuration: Environment and rendering configuration.
    ///     Defaults to `.init()` (no environment patches).
    ///   - viewBuilder: A closure that creates the SwiftUI view for the
    ///     current model state. Called once per step during `run`.
    public init(
        model: Model,
        configuration: FlowConfiguration = .init(),
        @ViewBuilder viewBuilder: @escaping @MainActor @Sendable (Model) -> Content
    ) {
        self.model = model
        self.configuration = configuration
        self.viewBuilder = viewBuilder
    }

    // MARK: - Step Building

    /// Adds a step with an action and an array of named assertions.
    ///
    /// - Parameters:
    ///   - name: Identifier for the step (used in snapshot file names).
    ///   - action: Closure that mutates the model. Defaults to no-op.
    ///   - assertions: Zero or more `FlowAssertion` values.
    /// - Returns: `self` for chaining.
    @discardableResult
    public func step(
        _ name: String,
        action: @escaping @MainActor @Sendable (Model) -> Void = { _ in },
        assertions: [FlowAssertion<Model>] = []
    ) -> Self {
        steps.append(FlowStep(name: name, action: action, assertions: assertions))
        return self
    }

    /// Adds a step with an action and a single assertion closure.
    ///
    /// Convenience overload for the common case of one assertion per step.
    ///
    /// - Parameters:
    ///   - name: Identifier for the step.
    ///   - action: Closure that mutates the model. Defaults to no-op.
    ///   - assert: A single assertion closure.
    /// - Returns: `self` for chaining.
    @discardableResult
    public func step(
        _ name: String,
        action: @escaping @MainActor @Sendable (Model) -> Void = { _ in },
        assert: @escaping @MainActor @Sendable (Model) -> Void
    ) -> Self {
        steps.append(
            FlowStep(
                name: name,
                action: action,
                assertions: [FlowAssertion(body: assert)]
            )
        )
        return self
    }

    // MARK: - Introspection

    /// The number of steps currently registered.
    public var stepCount: Int { steps.count }

    /// The names of all registered steps, in order.
    public var stepNames: [String] { steps.map(\.name) }

    // MARK: - Execution

    /// Executes the flow.
    ///
    /// For each step, in order:
    /// 1. Runs the step's action against the model.
    /// 2. Builds the view via the `viewBuilder` closure.
    /// 3. Applies environment patches from `configuration`.
    /// 4. Calls the `snapshot` closure with the step name and the
    ///    rendered `AnyView`.
    /// 5. Runs all of the step's assertions against the model.
    ///
    /// - Parameter snapshot: A closure that receives the step name and
    ///   rendered view. Typically wraps `assertSnapshot(of:as:named:)`.
    /// - Returns: An array of `FlowStepResult` describing each executed step.
    @discardableResult
    public func run(
        snapshot: @MainActor (String, AnyView) -> Void
    ) -> [FlowStepResult] {
        var results: [FlowStepResult] = []

        for (index, step) in steps.enumerated() {
            // 1. Execute the action (mutate the model).
            step.action(model)

            // 2. Build the view for the current model state.
            let content = viewBuilder(model)

            // 3. Apply environment patches and type-erase.
            var env = EnvironmentValues()
            configuration.environmentPatch(&env)
            let view = AnyView(
                content.environment(\.self, env)
            )

            // 4. Deliver to the snapshot closure.
            snapshot(step.name, view)

            // 5. Run assertions.
            for assertion in step.assertions {
                assertion.body(model)
            }

            results.append(FlowStepResult(stepName: step.name, index: index))
        }

        return results
    }
}
```

---

## Consumer Usage (Swift Testing + SnapshotTesting)

This section shows how consuming apps use the library. This code lives in the
consumer's test target, not in SwiftUIFlowTesting.

### Basic Flow Test

```swift
import Testing
import SwiftUI
import SnapshotTesting
import SwiftUIFlowTesting
@testable import MyApp

@Suite("Checkout Flow")
@MainActor
struct CheckoutFlowTests {

    @Test func happyPath() {
        let model = CheckoutModel(cart: .fixtureMultipleItems)

        FlowTester(model: model) { model in
            CheckoutView(model: model)
        }
        .step("cart") { _ in
            // Initial state, no action needed.
        } assert: { model in
            #expect(model.screen == .cart)
        }
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

### Dark Mode / Locale Override

```swift
@Test func darkModeJapanese() {
    let config = FlowConfiguration { env in
        env.colorScheme = .dark
        env.locale = Locale(identifier: "ja_JP")
    }

    FlowTester(model: CheckoutModel(cart: .fixture), configuration: config) { model in
        CheckoutView(model: model)
    }
    .step("cart") { _ in }
    .step("payment") { $0.proceedToPayment() }
    .run { name, view in
        assertSnapshot(of: view, as: .image, named: "\(name)_dark_ja")
    }
}
```

### Multiple Assertions Per Step

```swift
.step("payment", action: { $0.proceedToPayment() }, assertions: [
    FlowAssertion("screen is payment") { #expect($0.screen == .payment) },
    FlowAssertion("submit enabled") { #expect($0.isSubmitEnabled) },
    FlowAssertion("no error") { #expect($0.errorMessage == nil) },
])
```

### App-Side Model Conformance

```swift
import SwiftUI

@Observable
final class CheckoutModel: FlowModel {
    var screen: Screen = .cart
    var isSubmitEnabled = true
    var errorMessage: String?

    func proceedToPayment() { screen = .payment }
    func confirmOrder() { screen = .confirmation }
}
```

### App-Side View

```swift
struct CheckoutView: View {
    @Bindable var model: CheckoutModel

    var body: some View {
        switch model.screen {
        case .cart:
            CartContentView(model: model)
        case .payment:
            PaymentContentView(model: model)
        case .confirmation:
            ConfirmationContentView(model: model)
        }
    }
}
```

---

## File Layout

```
Sources/
  SwiftUIFlowTesting/
    FlowModel.swift            -- FlowModel protocol
    FlowAssertion.swift        -- FlowAssertion<Model>
    FlowStep.swift             -- FlowStep<Model>
    FlowStepResult.swift       -- FlowStepResult
    FlowConfiguration.swift    -- FlowConfiguration
    FlowTester.swift           -- FlowTester<Model, Content>
Tests/
  SwiftUIFlowTestingTests/
    FlowStepTests.swift        -- FlowStep construction, Sendable
    FlowConfigurationTests.swift
    FlowTesterTests.swift      -- Step building, run execution, results
```

---

## Type Summary

| Type                | Kind       | Sendable | Actor      | Generic Parameters        |
|---------------------|------------|----------|------------|---------------------------|
| `FlowModel`         | Protocol   | --       | --         | --                        |
| `FlowAssertion`     | Struct     | Yes      | --         | `<Model: FlowModel>`     |
| `FlowStep`          | Struct     | Yes      | --         | `<Model: FlowModel>`     |
| `FlowStepResult`    | Struct     | Yes      | --         | --                        |
| `FlowConfiguration` | Struct     | Yes      | --         | --                        |
| `FlowTester`        | Class      | No       | @MainActor | `<Model: FlowModel, Content: View>` |
