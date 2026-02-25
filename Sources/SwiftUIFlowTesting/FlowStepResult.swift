/// The result of executing a single flow step.
///
/// Returned by `FlowTester.run(snapshot:)` for optional post-run
/// inspection (e.g., logging step names and timing in CI output).
public struct FlowStepResult: Sendable {
    /// The original name of the step as declared in the builder.
    public let stepName: String

    /// The resolved name (includes tester name prefix; auto-generated for unnamed steps).
    public let resolvedName: String

    /// The index of this step in the flow (zero-based).
    public let index: Int

    /// The wall-clock duration of the step execution (action + snapshot + assertions).
    @_spi(Experimental)
    public let duration: Duration

    /// The number of assertions executed in this step.
    @_spi(Experimental)
    public let assertionCount: Int

    /// The configuration label when this step was part of a matrix run; `nil` otherwise.
    @_spi(Experimental)
    public let configurationLabel: String?

    /// The result of the built-in snapshot capture, or `nil` when using the closure API.
    public let snapshotResult: SnapshotResult?
}
