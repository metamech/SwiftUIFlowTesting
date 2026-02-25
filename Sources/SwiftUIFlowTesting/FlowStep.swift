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
    /// Empty string for unnamed steps (auto-named by `FlowTester`).
    public let name: String

    /// The synchronous action to perform on the model.
    public let action: @MainActor @Sendable (Model) -> Void

    /// An optional async action. When present, `asyncRun()` uses this
    /// instead of `action`.
    public let asyncAction: (@MainActor @Sendable (Model) async -> Void)?

    /// Assertions to run after the action and snapshot capture.
    public let assertions: [FlowAssertion<Model>]

    /// Creates a flow step.
    ///
    /// - Parameters:
    ///   - name: Identifier for the step (used in snapshot file names).
    ///   - action: Closure that mutates the model to simulate interaction.
    ///   - asyncAction: Optional async closure used by `asyncRun()`.
    ///   - assertions: Zero or more assertions to verify model state.
    public init(
        name: String,
        action: @escaping @MainActor @Sendable (Model) -> Void,
        asyncAction: (@MainActor @Sendable (Model) async -> Void)? = nil,
        assertions: [FlowAssertion<Model>] = []
    ) {
        self.name = name
        self.action = action
        self.asyncAction = asyncAction
        self.assertions = assertions
    }
}
