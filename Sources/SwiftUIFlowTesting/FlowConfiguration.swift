import SwiftUI

/// Configuration for a flow test run.
///
/// Controls how the tester prepares the SwiftUI environment before
/// rendering each step's view. Consumers use this to inject color
/// scheme, locale, dynamic type size, or other environment overrides.
///
/// Example:
/// ```swift
/// let config = FlowConfiguration { env in
///     env.colorScheme = .dark
///     env.locale = Locale(identifier: "ja_JP")
/// }
/// ```
public struct FlowConfiguration: Sendable {
    /// A closure that patches `EnvironmentValues` before each view render.
    /// Runs on `@MainActor` because `EnvironmentValues` is a SwiftUI type.
    public let environmentPatch: @MainActor @Sendable (inout EnvironmentValues) -> Void

    /// Creates a flow configuration.
    ///
    /// - Parameter environmentPatch: A closure to customize the SwiftUI
    ///   environment for rendered views. Defaults to no-op.
    public init(
        environmentPatch: @escaping @MainActor @Sendable (inout EnvironmentValues) -> Void = { _ in }
    ) {
        self.environmentPatch = environmentPatch
    }
}
