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
