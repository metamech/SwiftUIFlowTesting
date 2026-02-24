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
