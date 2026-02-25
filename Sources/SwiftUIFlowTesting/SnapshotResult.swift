import Foundation

/// The outcome of a single snapshot capture operation.
///
/// Produced by the built-in snapshot engine for each flow step.
/// Contains the comparison status and the rendered PNG data (when available).
public struct SnapshotResult: Sendable {
    /// The outcome of comparing a rendered snapshot against its reference.
    public enum Status: Sendable {
        /// The rendered image matched the reference exactly.
        case matched
        /// No reference existed; a new one was recorded at `path`.
        case newReference(path: String)
        /// The rendered image differs from the reference.
        case mismatch(referencePath: String, actualPath: String)
        /// Snapshotting was explicitly disabled for this step.
        case skipped
        /// The snapshot engine is not available on this platform.
        case unavailable
    }

    /// The comparison status for this snapshot.
    public let status: Status

    /// The rendered PNG data, or `nil` if rendering was skipped or unavailable.
    public let pngData: Data?

    /// Creates a snapshot result.
    ///
    /// - Parameters:
    ///   - status: The comparison status.
    ///   - pngData: The rendered PNG data.
    public init(status: Status, pngData: Data? = nil) {
        self.status = status
        self.pngData = pngData
    }
}
