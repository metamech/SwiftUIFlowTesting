import SwiftUI

/// An optional protocol for models that provide a default view.
///
/// When a model conforms to `FlowViewProvider`, `FlowTester` can be
/// initialized without an explicit `@ViewBuilder` closure.
///
/// Example:
/// ```swift
/// extension ContentViewModel: FlowViewProvider {
///     var flowBody: some View { ContentView(model: self) }
/// }
///
/// // Then tests become:
/// FlowTester(name: "content", model: vm)
///     .step("initial") { _ in }
///     .run()
/// ```
public protocol FlowViewProvider: FlowModel {
    associatedtype FlowBody: View
    @MainActor var flowBody: FlowBody { get }
}
