import SwiftUI

/// Selects the snapshotting strategy for a flow test run.
///
/// - `.builtin()`: Uses the built-in `ImageRenderer`-based engine.
/// - `.custom(closure)`: Delegates to a consumer-provided closure.
/// - `.disabled`: Skips all snapshotting.
public enum SnapshotMode: Sendable {
    /// Use the built-in `ImageRenderer`-based snapshot engine.
    case builtin(SnapshotConfiguration = .init())

    /// Delegate to a consumer-provided closure (e.g., swift-snapshot-testing).
    case custom(@MainActor @Sendable (String, AnyView) -> Void)

    /// Skip snapshotting entirely.
    case disabled
}
