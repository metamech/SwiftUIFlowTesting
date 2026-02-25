import SwiftUI

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
///     FlowTester(name: "checkout", model: model) { model in
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
    /// An optional name for this flow tester.
    /// When set, snapshot names become `"{name}-{stepName}"` and
    /// unnamed steps auto-generate as `"{name}-step-{index}"`.
    public let name: String?

    /// The model instance being driven through the flow.
    public let model: Model

    /// The configuration controlling environment patches.
    public let configuration: FlowConfiguration

    private let viewBuilder: @MainActor @Sendable (Model) -> Content
    private var flowSteps: [FlowStep<Model>] = []
    private var beforeHook: (@MainActor @Sendable (String, Int, Model) -> Void)?
    private var afterHook: (@MainActor @Sendable (String, Int, Model) -> Void)?

    // MARK: - Initialization

    /// Creates a flow tester.
    ///
    /// - Parameters:
    ///   - name: An optional name for the flow. When set, step names are
    ///     prefixed and unnamed steps are auto-generated.
    ///   - model: The model instance to drive through the flow.
    ///   - configuration: Environment and rendering configuration.
    ///     Defaults to `.init()` (no environment patches).
    ///   - viewBuilder: A closure that creates the SwiftUI view for the
    ///     current model state. Called once per step during `run`.
    public init(
        name: String? = nil,
        model: Model,
        configuration: FlowConfiguration = .init(),
        @ViewBuilder viewBuilder: @escaping @MainActor @Sendable (Model) -> Content
    ) {
        self.name = name
        self.model = model
        self.configuration = configuration
        self.viewBuilder = viewBuilder
    }

    // MARK: - Step Building (Named)

    /// Adds a named step with an action and an array of assertions.
    ///
    /// - Parameters:
    ///   - name: Identifier for the step (used in snapshot file names).
    ///   - snapshot: Whether to capture a snapshot for this step. Defaults to `true`.
    ///   - action: Closure that mutates the model. Defaults to no-op.
    ///   - assertions: Zero or more `FlowAssertion` values.
    /// - Returns: `self` for chaining.
    @discardableResult
    public func step(
        _ name: String,
        snapshot: Bool = true,
        action: @escaping @MainActor @Sendable (Model) -> Void = { _ in },
        assertions: [FlowAssertion<Model>] = []
    ) -> Self {
        flowSteps.append(
            FlowStep(name: name, action: action, assertions: assertions, snapshotEnabled: snapshot)
        )
        return self
    }

    /// Adds a named step with an action and a single assertion closure.
    ///
    /// - Parameters:
    ///   - name: Identifier for the step.
    ///   - snapshot: Whether to capture a snapshot for this step. Defaults to `true`.
    ///   - action: Closure that mutates the model.
    ///   - assert: A single assertion closure.
    /// - Returns: `self` for chaining.
    @discardableResult
    public func step(
        _ name: String,
        snapshot: Bool = true,
        action: @escaping @MainActor @Sendable (Model) -> Void,
        assert: @escaping @MainActor @Sendable (Model) -> Void
    ) -> Self {
        flowSteps.append(
            FlowStep(
                name: name,
                action: action,
                assertions: [FlowAssertion(body: assert)],
                snapshotEnabled: snapshot
            )
        )
        return self
    }

    // MARK: - Step Building (Unnamed)

    /// Adds an unnamed step with an action and an array of assertions.
    ///
    /// The step name is auto-generated as `"{testerName}-step-{index}"`
    /// or `"step-{index}"` if the tester has no name.
    ///
    /// - Parameters:
    ///   - snapshot: Whether to capture a snapshot for this step. Defaults to `true`.
    ///   - action: Closure that mutates the model. Defaults to no-op.
    ///   - assertions: Zero or more `FlowAssertion` values.
    /// - Returns: `self` for chaining.
    @discardableResult
    public func step(
        snapshot: Bool = true,
        action: @escaping @MainActor @Sendable (Model) -> Void = { _ in },
        assertions: [FlowAssertion<Model>] = []
    ) -> Self {
        flowSteps.append(
            FlowStep(name: "", action: action, assertions: assertions, snapshotEnabled: snapshot)
        )
        return self
    }

    /// Adds an unnamed step with an action and a single assertion closure.
    ///
    /// - Parameters:
    ///   - snapshot: Whether to capture a snapshot for this step. Defaults to `true`.
    ///   - action: Closure that mutates the model.
    ///   - assert: A single assertion closure.
    /// - Returns: `self` for chaining.
    @discardableResult
    public func step(
        snapshot: Bool = true,
        action: @escaping @MainActor @Sendable (Model) -> Void,
        assert: @escaping @MainActor @Sendable (Model) -> Void
    ) -> Self {
        flowSteps.append(
            FlowStep(
                name: "",
                action: action,
                assertions: [FlowAssertion(body: assert)],
                snapshotEnabled: snapshot
            )
        )
        return self
    }

    // MARK: - Async Step Building

    /// Adds a named async step with an async action and an array of assertions.
    ///
    /// Async steps are executed by `asyncRun(snapshot:)`. The synchronous
    /// `run(snapshot:)` ignores async actions and uses the no-op sync fallback.
    ///
    /// - Parameters:
    ///   - name: Identifier for the step.
    ///   - snapshot: Whether to capture a snapshot for this step. Defaults to `true`.
    ///   - action: An async closure that mutates the model.
    ///   - assertions: Zero or more `FlowAssertion` values.
    /// - Returns: `self` for chaining.
    @_spi(Experimental)
    @discardableResult
    public func asyncStep(
        _ name: String,
        snapshot: Bool = true,
        action: @escaping @MainActor @Sendable (Model) async -> Void,
        assertions: [FlowAssertion<Model>] = []
    ) -> Self {
        flowSteps.append(
            FlowStep(
                name: name,
                action: { _ in },
                asyncAction: action,
                assertions: assertions,
                snapshotEnabled: snapshot
            )
        )
        return self
    }

    /// Adds a named async step with an async action and a single assertion.
    ///
    /// - Parameters:
    ///   - name: Identifier for the step.
    ///   - snapshot: Whether to capture a snapshot for this step. Defaults to `true`.
    ///   - action: An async closure that mutates the model.
    ///   - assert: A single assertion closure.
    /// - Returns: `self` for chaining.
    @_spi(Experimental)
    @discardableResult
    public func asyncStep(
        _ name: String,
        snapshot: Bool = true,
        action: @escaping @MainActor @Sendable (Model) async -> Void,
        assert: @escaping @MainActor @Sendable (Model) -> Void
    ) -> Self {
        flowSteps.append(
            FlowStep(
                name: name,
                action: { _ in },
                asyncAction: action,
                assertions: [FlowAssertion(body: assert)],
                snapshotEnabled: snapshot
            )
        )
        return self
    }

    // MARK: - Lifecycle Hooks

    /// Registers a hook called before each step's action.
    ///
    /// The hook receives the resolved step name, index, and model.
    ///
    /// - Parameter hook: Closure called before each step.
    /// - Returns: `self` for chaining.
    @discardableResult
    public func beforeEachStep(
        _ hook: @escaping @MainActor @Sendable (String, Int, Model) -> Void
    ) -> Self {
        beforeHook = hook
        return self
    }

    /// Registers a hook called after each step's assertions.
    ///
    /// The hook receives the resolved step name, index, and model.
    ///
    /// - Parameter hook: Closure called after each step.
    /// - Returns: `self` for chaining.
    @discardableResult
    public func afterEachStep(
        _ hook: @escaping @MainActor @Sendable (String, Int, Model) -> Void
    ) -> Self {
        afterHook = hook
        return self
    }

    // MARK: - Composition

    /// The steps currently registered, for extraction and reuse.
    @_spi(Experimental)
    public var extractedSteps: [FlowStep<Model>] { flowSteps }

    /// Appends an array of steps (e.g., extracted from another tester).
    ///
    /// Auto-named steps renumber naturally based on their new index.
    ///
    /// - Parameter newSteps: Steps to append.
    /// - Returns: `self` for chaining.
    @_spi(Experimental)
    @discardableResult
    public func steps(_ newSteps: [FlowStep<Model>]) -> Self {
        flowSteps.append(contentsOf: newSteps)
        return self
    }

    // MARK: - Introspection

    /// The number of steps currently registered.
    public var stepCount: Int { flowSteps.count }

    /// The resolved names of all registered steps, in order.
    public var stepNames: [String] {
        flowSteps.enumerated().map { index, step in
            resolvedName(for: step.name, at: index)
        }
    }

    // MARK: - Name Resolution

    private func resolvedName(for stepName: String, at index: Int) -> String {
        if stepName.isEmpty {
            return name.map { "\($0)-step-\(index)" } ?? "step-\(index)"
        }
        return name.map { "\($0)-\(stepName)" } ?? stepName
    }

    private func resolvedName(
        for stepName: String,
        at index: Int,
        configLabel: String?
    ) -> String {
        let base = resolvedName(for: stepName, at: index)
        if let label = configLabel, !label.isEmpty {
            return "\(base)-\(label)"
        }
        return base
    }

    // MARK: - Shared Step Execution

    private func executeStep(
        _ step: FlowStep<Model>,
        index: Int,
        on targetModel: Model,
        config: FlowConfiguration,
        configLabel: String?,
        snapshot: @MainActor (String, AnyView) -> Void,
        snapshotEngine: SnapshotEngine?,
        clock: ContinuousClock
    ) -> FlowStepResult {
        let resolved = resolvedName(for: step.name, at: index, configLabel: configLabel)
        let start = clock.now

        beforeHook?(resolved, index, targetModel)

        step.action(targetModel)

        let content = viewBuilder(targetModel)
        var env = EnvironmentValues()
        config.environmentPatch(&env)
        let view = AnyView(content.environment(\.self, env))

        var snapshotResult: SnapshotResult?
        if step.snapshotEnabled {
            if let engine = snapshotEngine {
                snapshotResult = engine.capture(name: resolved, view: view)
            } else {
                snapshot(resolved, view)
            }
        } else {
            snapshotResult = SnapshotResult(status: .skipped)
        }

        for assertion in step.assertions {
            assertion.body(targetModel)
        }

        afterHook?(resolved, index, targetModel)

        let elapsed = clock.now - start

        return FlowStepResult(
            stepName: step.name,
            resolvedName: resolved,
            index: index,
            duration: elapsed,
            assertionCount: step.assertions.count,
            configurationLabel: configLabel,
            snapshotResult: snapshotResult
        )
    }

    private func executeStepAsync(
        _ step: FlowStep<Model>,
        index: Int,
        on targetModel: Model,
        config: FlowConfiguration,
        configLabel: String?,
        snapshot: @MainActor (String, AnyView) -> Void,
        snapshotEngine: SnapshotEngine?,
        clock: ContinuousClock
    ) async -> FlowStepResult {
        let resolved = resolvedName(for: step.name, at: index, configLabel: configLabel)
        let start = clock.now

        beforeHook?(resolved, index, targetModel)

        if let asyncAction = step.asyncAction {
            await asyncAction(targetModel)
        } else {
            step.action(targetModel)
        }

        let content = viewBuilder(targetModel)
        var env = EnvironmentValues()
        config.environmentPatch(&env)
        let view = AnyView(content.environment(\.self, env))

        var snapshotResult: SnapshotResult?
        if step.snapshotEnabled {
            if let engine = snapshotEngine {
                snapshotResult = engine.capture(name: resolved, view: view)
            } else {
                snapshot(resolved, view)
            }
        } else {
            snapshotResult = SnapshotResult(status: .skipped)
        }

        for assertion in step.assertions {
            assertion.body(targetModel)
        }

        afterHook?(resolved, index, targetModel)

        let elapsed = clock.now - start

        return FlowStepResult(
            stepName: step.name,
            resolvedName: resolved,
            index: index,
            duration: elapsed,
            assertionCount: step.assertions.count,
            configurationLabel: configLabel,
            snapshotResult: snapshotResult
        )
    }

    // MARK: - Execution (Closure API)

    /// Executes the flow synchronously.
    ///
    /// For each step, in order:
    /// 1. Calls the `beforeEachStep` hook (if registered).
    /// 2. Runs the step's synchronous action against the model.
    /// 3. Builds the view via the `viewBuilder` closure.
    /// 4. Applies environment patches from `configuration`.
    /// 5. Calls the `snapshot` closure with the resolved name and view.
    /// 6. Runs all of the step's assertions against the model.
    /// 7. Calls the `afterEachStep` hook (if registered).
    ///
    /// - Parameter snapshot: A closure that receives the resolved step name
    ///   and rendered view. Typically wraps `assertSnapshot(of:as:named:)`.
    /// - Returns: An array of `FlowStepResult` describing each executed step.
    @discardableResult
    public func run(
        snapshot: @MainActor (String, AnyView) -> Void
    ) -> [FlowStepResult] {
        let clock = ContinuousClock()
        return flowSteps.enumerated().map { index, step in
            executeStep(
                step,
                index: index,
                on: model,
                config: configuration,
                configLabel: nil,
                snapshot: snapshot,
                snapshotEngine: nil,
                clock: clock
            )
        }
    }

    // MARK: - Execution (Built-in Snapshot API)

    /// Executes the flow with built-in snapshotting.
    ///
    /// Uses `ImageRenderer` to capture each step's view as a PNG,
    /// compares against reference images on disk, and returns results
    /// with `snapshotResult` populated.
    ///
    /// - Parameters:
    ///   - snapshotMode: The snapshot strategy. Defaults to `.builtin()`.
    ///   - filePath: The test file path (captured automatically via `#filePath`).
    ///   - function: The test function name (captured automatically via `#function`).
    /// - Returns: An array of `FlowStepResult` describing each executed step.
    @discardableResult
    public func run(
        snapshotMode: SnapshotMode = .builtin(),
        filePath: String = #filePath,
        function: String = #function
    ) -> [FlowStepResult] {
        let clock = ContinuousClock()

        switch snapshotMode {
        case .builtin(let config):
            let engine = SnapshotEngine(
                configuration: config,
                filePath: filePath,
                function: function
            )
            return flowSteps.enumerated().map { index, step in
                executeStep(
                    step,
                    index: index,
                    on: model,
                    config: configuration,
                    configLabel: nil,
                    snapshot: { _, _ in },
                    snapshotEngine: engine,
                    clock: clock
                )
            }
        case .custom(let closure):
            return flowSteps.enumerated().map { index, step in
                executeStep(
                    step,
                    index: index,
                    on: model,
                    config: configuration,
                    configLabel: nil,
                    snapshot: closure,
                    snapshotEngine: nil,
                    clock: clock
                )
            }
        case .disabled:
            return flowSteps.enumerated().map { index, step in
                executeStep(
                    step,
                    index: index,
                    on: model,
                    config: configuration,
                    configLabel: nil,
                    snapshot: { _, _ in },
                    snapshotEngine: nil,
                    clock: clock
                )
            }
        }
    }

    // MARK: - Async Execution (Closure API)

    /// Executes the flow with async step support.
    ///
    /// For steps with an `asyncAction`, runs the async action. For steps
    /// without one, falls back to the synchronous action. Otherwise
    /// behaves identically to `run(snapshot:)`.
    ///
    /// - Parameter snapshot: A closure that receives the resolved step name
    ///   and rendered view.
    /// - Returns: An array of `FlowStepResult` describing each executed step.
    @_spi(Experimental)
    @discardableResult
    public func asyncRun(
        snapshot: @MainActor (String, AnyView) -> Void
    ) async -> [FlowStepResult] {
        let clock = ContinuousClock()
        var results: [FlowStepResult] = []

        for (index, step) in flowSteps.enumerated() {
            let result = await executeStepAsync(
                step,
                index: index,
                on: model,
                config: configuration,
                configLabel: nil,
                snapshot: snapshot,
                snapshotEngine: nil,
                clock: clock
            )
            results.append(result)
        }

        return results
    }

    // MARK: - Async Execution (Built-in Snapshot API)

    /// Executes the flow asynchronously with built-in snapshotting.
    ///
    /// - Parameters:
    ///   - snapshotMode: The snapshot strategy. Defaults to `.builtin()`.
    ///   - filePath: The test file path (captured automatically via `#filePath`).
    ///   - function: The test function name (captured automatically via `#function`).
    /// - Returns: An array of `FlowStepResult` describing each executed step.
    @discardableResult
    public func asyncRun(
        snapshotMode: SnapshotMode = .builtin(),
        filePath: String = #filePath,
        function: String = #function
    ) async -> [FlowStepResult] {
        let clock = ContinuousClock()
        var results: [FlowStepResult] = []

        let engine: SnapshotEngine?
        let closure: (@MainActor @Sendable (String, AnyView) -> Void)?

        switch snapshotMode {
        case .builtin(let config):
            engine = SnapshotEngine(
                configuration: config,
                filePath: filePath,
                function: function
            )
            closure = nil
        case .custom(let c):
            engine = nil
            closure = c
        case .disabled:
            engine = nil
            closure = nil
        }

        for (index, step) in flowSteps.enumerated() {
            let result = await executeStepAsync(
                step,
                index: index,
                on: model,
                config: configuration,
                configLabel: nil,
                snapshot: closure ?? { _, _ in },
                snapshotEngine: engine,
                clock: clock
            )
            results.append(result)
        }

        return results
    }

    // MARK: - Matrix Execution (Closure API)

    /// Executes the flow once per configuration with a fresh model each time.
    ///
    /// For each configuration in `configurations`, creates a fresh model via
    /// `modelFactory`, runs all steps against it using that configuration's
    /// environment patch, and appends the results. Snapshot names incorporate
    /// the configuration label (e.g., `"checkout-cart-dark"`).
    ///
    /// - Parameters:
    ///   - configurations: The configurations to run the flow against.
    ///   - modelFactory: Creates a fresh model for each configuration.
    ///   - snapshot: A closure that receives the resolved step name and view.
    /// - Returns: An array of `FlowStepResult` for all configurations.
    @discardableResult
    public func matrixRun(
        configurations: [FlowConfiguration],
        modelFactory: @MainActor @Sendable () -> Model,
        snapshot: @MainActor (String, AnyView) -> Void
    ) -> [FlowStepResult] {
        let clock = ContinuousClock()
        var results: [FlowStepResult] = []

        for config in configurations {
            let matrixModel = modelFactory()

            for (index, step) in flowSteps.enumerated() {
                let result = executeStep(
                    step,
                    index: index,
                    on: matrixModel,
                    config: config,
                    configLabel: config.label,
                    snapshot: snapshot,
                    snapshotEngine: nil,
                    clock: clock
                )
                results.append(result)
            }
        }

        return results
    }

    // MARK: - Matrix Execution (Built-in Snapshot API)

    /// Executes the flow once per configuration with built-in snapshotting.
    ///
    /// - Parameters:
    ///   - configurations: The configurations to run the flow against.
    ///   - modelFactory: Creates a fresh model for each configuration.
    ///   - snapshotMode: The snapshot strategy. Defaults to `.builtin()`.
    ///   - filePath: The test file path (captured automatically via `#filePath`).
    ///   - function: The test function name (captured automatically via `#function`).
    /// - Returns: An array of `FlowStepResult` for all configurations.
    @discardableResult
    public func matrixRun(
        configurations: [FlowConfiguration],
        modelFactory: @MainActor @Sendable () -> Model,
        snapshotMode: SnapshotMode = .builtin(),
        filePath: String = #filePath,
        function: String = #function
    ) -> [FlowStepResult] {
        let clock = ContinuousClock()
        var results: [FlowStepResult] = []

        let engine: SnapshotEngine?
        let closure: (@MainActor @Sendable (String, AnyView) -> Void)?

        switch snapshotMode {
        case .builtin(let config):
            engine = SnapshotEngine(
                configuration: config,
                filePath: filePath,
                function: function
            )
            closure = nil
        case .custom(let c):
            engine = nil
            closure = c
        case .disabled:
            engine = nil
            closure = nil
        }

        for config in configurations {
            let matrixModel = modelFactory()

            for (index, step) in flowSteps.enumerated() {
                let result = executeStep(
                    step,
                    index: index,
                    on: matrixModel,
                    config: config,
                    configLabel: config.label,
                    snapshot: closure ?? { _, _ in },
                    snapshotEngine: engine,
                    clock: clock
                )
                results.append(result)
            }
        }

        return results
    }
}

// MARK: - FlowViewProvider Convenience Init

extension FlowTester where Content == AnyView {
    /// Creates a flow tester using the model's `flowBody` as the view.
    ///
    /// This convenience initializer is available when the model conforms to
    /// `FlowViewProvider`, eliminating the need for an explicit `@ViewBuilder`
    /// closure.
    ///
    /// - Parameters:
    ///   - name: An optional name for the flow.
    ///   - model: The model instance (must conform to `FlowViewProvider`).
    ///   - configuration: Environment and rendering configuration.
    public convenience init(
        name: String? = nil,
        model: Model,
        configuration: FlowConfiguration = .init()
    ) where Model: FlowViewProvider {
        self.init(name: name, model: model, configuration: configuration) { model in
            AnyView(model.flowBody)
        }
    }
}
