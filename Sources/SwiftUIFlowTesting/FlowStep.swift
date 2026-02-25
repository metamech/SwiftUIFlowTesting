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
    @_spi(Experimental)
    public let asyncAction: (@MainActor @Sendable (Model) async -> Void)?

    /// Assertions to run after the action and snapshot capture.
    public let assertions: [FlowAssertion<Model>]

    /// Whether snapshot capture is enabled for this step.
    /// When `false`, the step still executes its action and assertions
    /// but skips snapshot capture/comparison.
    public let snapshotEnabled: Bool

    /// Creates a flow step.
    ///
    /// - Parameters:
    ///   - name: Identifier for the step (used in snapshot file names).
    ///   - action: Closure that mutates the model to simulate interaction.
    ///   - assertions: Zero or more assertions to verify model state.
    ///   - snapshotEnabled: Whether to capture a snapshot for this step.
    public init(
        name: String,
        action: @escaping @MainActor @Sendable (Model) -> Void,
        assertions: [FlowAssertion<Model>] = [],
        snapshotEnabled: Bool = true
    ) {
        self.name = name
        self.action = action
        self.asyncAction = nil
        self.assertions = assertions
        self.snapshotEnabled = snapshotEnabled
    }

    /// Creates a flow step with an optional async action.
    ///
    /// - Parameters:
    ///   - name: Identifier for the step (used in snapshot file names).
    ///   - action: Closure that mutates the model to simulate interaction.
    ///   - asyncAction: Optional async closure used by `asyncRun()`.
    ///   - assertions: Zero or more assertions to verify model state.
    ///   - snapshotEnabled: Whether to capture a snapshot for this step.
    @_spi(Experimental)
    public init(
        name: String,
        action: @escaping @MainActor @Sendable (Model) -> Void,
        asyncAction: (@MainActor @Sendable (Model) async -> Void)?,
        assertions: [FlowAssertion<Model>] = [],
        snapshotEnabled: Bool = true
    ) {
        self.name = name
        self.action = action
        self.asyncAction = asyncAction
        self.assertions = assertions
        self.snapshotEnabled = snapshotEnabled
    }
}
