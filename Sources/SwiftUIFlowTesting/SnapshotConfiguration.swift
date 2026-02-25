import Foundation

/// Configuration for the built-in snapshot engine.
///
/// Controls rendering scale, proposed view size, recording behavior,
/// and the directory where reference images are stored.
///
/// Example:
/// ```swift
/// let config = SnapshotConfiguration(
///     scale: 3.0,
///     proposedSize: .init(width: 393, height: 852)
/// )
/// ```
public struct SnapshotConfiguration: Sendable {
    /// The rendering scale factor. Defaults to `2.0`.
    public let scale: CGFloat

    /// The proposed view size for rendering. Defaults to 390×844 (iPhone 14-class).
    public let proposedSize: ProposedSize

    /// When `true`, always overwrites reference images instead of comparing.
    /// Defaults to checking the `FLOW_RECORD_SNAPSHOTS` environment variable.
    public let record: Bool

    /// An explicit directory for reference images. When `nil`, the engine
    /// computes `__Snapshots__/{TestFileName}/` relative to the test file.
    public let snapshotDirectory: String?

    /// A proposed width and height for view rendering.
    public struct ProposedSize: Sendable {
        public let width: CGFloat
        public let height: CGFloat

        public init(width: CGFloat, height: CGFloat) {
            self.width = width
            self.height = height
        }
    }

    /// Creates a snapshot configuration.
    ///
    /// - Parameters:
    ///   - scale: Rendering scale factor. Defaults to `2.0`.
    ///   - proposedSize: View size for rendering. Defaults to 390×844.
    ///   - record: Force-record mode. Defaults to checking `FLOW_RECORD_SNAPSHOTS` env var.
    ///   - snapshotDirectory: Override the computed snapshot directory. Defaults to `nil`.
    public init(
        scale: CGFloat = 2.0,
        proposedSize: ProposedSize = .init(width: 390, height: 844),
        record: Bool = ProcessInfo.processInfo.environment["FLOW_RECORD_SNAPSHOTS"] != nil,
        snapshotDirectory: String? = nil
    ) {
        self.scale = scale
        self.proposedSize = proposedSize
        self.record = record
        self.snapshotDirectory = snapshotDirectory
    }
}
