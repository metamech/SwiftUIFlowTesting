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
