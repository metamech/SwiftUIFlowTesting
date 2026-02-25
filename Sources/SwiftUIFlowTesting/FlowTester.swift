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
    ///   - action: Closure that mutates the model. Defaults to no-op.
    ///   - assertions: Zero or more `FlowAssertion` values.
    /// - Returns: `self` for chaining.
    @discardableResult
    public func step(
        _ name: String,
        action: @escaping @MainActor @Sendable (Model) -> Void = { _ in },
        assertions: [FlowAssertion<Model>] = []
    ) -> Self {
        flowSteps.append(FlowStep(name: name, action: action, assertions: assertions))
        return self
    }

    /// Adds a named step with an action and a single assertion closure.
    ///
    /// - Parameters:
    ///   - name: Identifier for the step.
    ///   - action: Closure that mutates the model.
    ///   - assert: A single assertion closure.
    /// - Returns: `self` for chaining.
    @discardableResult
    public func step(
        _ name: String,
        action: @escaping @MainActor @Sendable (Model) -> Void,
        assert: @escaping @MainActor @Sendable (Model) -> Void
    ) -> Self {
        flowSteps.append(
            FlowStep(
                name: name,
                action: action,
                assertions: [FlowAssertion(body: assert)]
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
    ///   - action: Closure that mutates the model. Defaults to no-op.
    ///   - assertions: Zero or more `FlowAssertion` values.
    /// - Returns: `self` for chaining.
    @discardableResult
    public func step(
        action: @escaping @MainActor @Sendable (Model) -> Void = { _ in },
        assertions: [FlowAssertion<Model>] = []
    ) -> Self {
        flowSteps.append(FlowStep(name: "", action: action, assertions: assertions))
        return self
    }

    /// Adds an unnamed step with an action and a single assertion closure.
    ///
    /// - Parameters:
    ///   - action: Closure that mutates the model.
    ///   - assert: A single assertion closure.
    /// - Returns: `self` for chaining.
    @discardableResult
    public func step(
        action: @escaping @MainActor @Sendable (Model) -> Void,
        assert: @escaping @MainActor @Sendable (Model) -> Void
    ) -> Self {
        flowSteps.append(
            FlowStep(
                name: "",
                action: action,
                assertions: [FlowAssertion(body: assert)]
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
    ///   - action: An async closure that mutates the model.
    ///   - assertions: Zero or more `FlowAssertion` values.
    /// - Returns: `self` for chaining.
    @_spi(Experimental)
    @discardableResult
    public func asyncStep(
        _ name: String,
        action: @escaping @MainActor @Sendable (Model) async -> Void,
        assertions: [FlowAssertion<Model>] = []
    ) -> Self {
        flowSteps.append(
            FlowStep(
                name: name,
                action: { _ in },
                asyncAction: action,
                assertions: assertions
            )
        )
        return self
    }

    /// Adds a named async step with an async action and a single assertion.
    ///
    /// - Parameters:
    ///   - name: Identifier for the step.
    ///   - action: An async closure that mutates the model.
    ///   - assert: A single assertion closure.
    /// - Returns: `self` for chaining.
    @_spi(Experimental)
    @discardableResult
    public func asyncStep(
        _ name: String,
        action: @escaping @MainActor @Sendable (Model) async -> Void,
        assert: @escaping @MainActor @Sendable (Model) -> Void
    ) -> Self {
        flowSteps.append(
            FlowStep(
                name: name,
                action: { _ in },
                asyncAction: action,
                assertions: [FlowAssertion(body: assert)]
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

    // MARK: - Execution

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
        var results: [FlowStepResult] = []

        for (index, step) in flowSteps.enumerated() {
            let resolved = resolvedName(for: step.name, at: index)
            let start = clock.now

            beforeHook?(resolved, index, model)

            step.action(model)

            let content = viewBuilder(model)
            var env = EnvironmentValues()
            configuration.environmentPatch(&env)
            let view = AnyView(content.environment(\.self, env))

            snapshot(resolved, view)

            for assertion in step.assertions {
                assertion.body(model)
            }

            afterHook?(resolved, index, model)

            let elapsed = clock.now - start

            results.append(
                FlowStepResult(
                    stepName: step.name,
                    resolvedName: resolved,
                    index: index,
                    duration: elapsed,
                    assertionCount: step.assertions.count,
                    configurationLabel: nil
                )
            )
        }

        return results
    }

    // MARK: - Async Execution

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
            let resolved = resolvedName(for: step.name, at: index)
            let start = clock.now

            beforeHook?(resolved, index, model)

            if let asyncAction = step.asyncAction {
                await asyncAction(model)
            } else {
                step.action(model)
            }

            let content = viewBuilder(model)
            var env = EnvironmentValues()
            configuration.environmentPatch(&env)
            let view = AnyView(content.environment(\.self, env))

            snapshot(resolved, view)

            for assertion in step.assertions {
                assertion.body(model)
            }

            afterHook?(resolved, index, model)

            let elapsed = clock.now - start

            results.append(
                FlowStepResult(
                    stepName: step.name,
                    resolvedName: resolved,
                    index: index,
                    duration: elapsed,
                    assertionCount: step.assertions.count,
                    configurationLabel: nil
                )
            )
        }

        return results
    }

    // MARK: - Matrix Execution

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
    @_spi(Experimental)
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
                let resolved = resolvedName(
                    for: step.name,
                    at: index,
                    configLabel: config.label
                )
                let start = clock.now

                beforeHook?(resolved, index, matrixModel)

                step.action(matrixModel)

                let content = viewBuilder(matrixModel)
                var env = EnvironmentValues()
                config.environmentPatch(&env)
                let view = AnyView(content.environment(\.self, env))

                snapshot(resolved, view)

                for assertion in step.assertions {
                    assertion.body(matrixModel)
                }

                afterHook?(resolved, index, matrixModel)

                let elapsed = clock.now - start

                results.append(
                    FlowStepResult(
                        stepName: step.name,
                        resolvedName: resolved,
                        index: index,
                        duration: elapsed,
                        assertionCount: step.assertions.count,
                        configurationLabel: config.label
                    )
                )
            }
        }

        return results
    }
}
