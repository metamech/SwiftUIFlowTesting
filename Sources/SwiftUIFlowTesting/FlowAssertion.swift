import SwiftUI

#if canImport(AppKit)
import AppKit
#endif

/// A single named assertion to run against a model after a flow step.
///
/// The `label` aids diagnostics when an assertion fails. The `body` closure
/// runs on `@MainActor` and receives the current model state.
///
/// Example:
/// ```swift
/// FlowAssertion("screen is payment") { model in
///     #expect(model.screen == .payment)
/// }
/// ```
public struct FlowAssertion<Model: FlowModel>: Sendable {
    /// A human-readable label describing what this assertion checks.
    public let label: String

    /// The assertion body. Runs on `@MainActor` after the step action
    /// and snapshot capture.
    public let body: @MainActor @Sendable (Model) -> Void

    /// Creates a named assertion.
    ///
    /// - Parameters:
    ///   - label: A description of what this assertion verifies.
    ///   - body: A closure that performs the assertion against the model.
    public init(
        _ label: String = "",
        body: @escaping @MainActor @Sendable (Model) -> Void
    ) {
        self.label = label
        self.body = body
    }
}

// MARK: - Accessibility Assertions

#if canImport(AppKit)
extension FlowAssertion {
    /// Creates an assertion that checks whether an accessibility element with the given
    /// identifier exists in the rendered view.
    ///
    /// The assertion hosts the view built from the current model in an `NSHostingView` and
    /// walks the accessibility hierarchy to find a matching identifier.
    ///
    /// - Parameters:
    ///   - identifier: The accessibility identifier to search for.
    ///   - exists: Whether the identifier should exist (`true`) or not (`false`). Defaults to `true`.
    ///   - viewBuilder: A closure that builds the SwiftUI view from the model.
    /// - Returns: A `FlowAssertion` that validates accessibility presence.
    @MainActor
    public static func accessibility<V: View>(
        identifier: String,
        exists: Bool = true,
        in viewBuilder: @escaping @MainActor @Sendable (Model) -> V
    ) -> FlowAssertion {
        FlowAssertion("accessibility(\(identifier), exists: \(exists))") { model in
            let view = viewBuilder(model)
            let hostingView = NSHostingView(rootView: view)
            hostingView.frame = NSRect(x: 0, y: 0, width: 400, height: 400)
            hostingView.layout()

            let found = accessibilityDescendantExists(
                element: hostingView,
                identifier: identifier
            )

            if exists {
                precondition(found, "Expected accessibility identifier '\(identifier)' to exist, but it was not found")
            } else {
                precondition(!found, "Expected accessibility identifier '\(identifier)' to NOT exist, but it was found")
            }
        }
    }

    /// Recursively walks the accessibility hierarchy looking for a matching identifier.
    @MainActor
    private static func accessibilityDescendantExists(
        element: Any,
        identifier: String
    ) -> Bool {
        guard let accessible = element as? NSAccessibilityElementProtocol else {
            return false
        }

        // Check if this element's identifier matches
        if let identifiable = accessible as? NSAccessibilityProtocol,
           let id = identifiable.accessibilityIdentifier(),
           id == identifier {
            return true
        }

        // Walk children
        if let parent = accessible as? NSAccessibilityProtocol,
           let children = parent.accessibilityChildren() {
            for child in children {
                if accessibilityDescendantExists(element: child, identifier: identifier) {
                    return true
                }
            }
        }

        return false
    }
}
#endif
