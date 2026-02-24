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
    ///   - action: Closure that mutates the model.
    ///   - assert: A single assertion closure.
    /// - Returns: `self` for chaining.
    @discardableResult
    public func step(
        _ name: String,
        action: @escaping @MainActor @Sendable (Model) -> Void,
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
            step.action(model)

            let content = viewBuilder(model)

            var env = EnvironmentValues()
            configuration.environmentPatch(&env)
            let view = AnyView(
                content.environment(\.self, env)
            )

            snapshot(step.name, view)

            for assertion in step.assertions {
                assertion.body(model)
            }

            results.append(FlowStepResult(stepName: step.name, index: index))
        }

        return results
    }
}
