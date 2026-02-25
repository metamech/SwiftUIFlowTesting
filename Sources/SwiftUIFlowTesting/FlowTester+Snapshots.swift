import Foundation

extension [FlowStepResult] {
    /// Passes each step's snapshot PNG data to a handler for attachment.
    ///
    /// Use this to bridge snapshot data into Swift Testing's `Attachment` API
    /// without the library importing `Testing` itself.
    ///
    /// Example:
    /// ```swift
    /// import Testing
    /// import SwiftUIFlowTesting
    ///
    /// @Test @MainActor func myFlow() {
    ///     FlowTester(model: model) { m in MyView(model: m) }
    ///         .step("cart") { $0.goToCart() }
    ///         .run()
    ///         .attachSnapshots { data, name in
    ///             Attachment.record(data, named: name)
    ///         }
    /// }
    /// ```
    ///
    /// - Parameter handler: A closure receiving PNG data and a suggested file name.
    public func attachSnapshots(using handler: (Data, String) -> Void) {
        for result in self {
            guard let pngData = result.snapshotResult?.pngData else { continue }
            handler(pngData, "\(result.resolvedName).png")
        }
    }
}
