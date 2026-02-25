import SwiftUI

/// Configuration for a flow test run.
///
/// Controls how the tester prepares the SwiftUI environment before
/// rendering each step's view. Consumers use this to inject color
/// scheme, locale, dynamic type size, or other environment overrides.
///
/// The `label` is used in matrix runs to disambiguate snapshot names
/// across configurations (e.g., `"dark"`, `"ja_JP"`).
///
/// Example:
/// ```swift
/// let config = FlowConfiguration(label: "dark") { env in
///     env.colorScheme = .dark
/// }
/// ```
public struct FlowConfiguration: Sendable {
    /// A label identifying this configuration (e.g., `"dark"`, `"large-text"`).
    /// Used in matrix run snapshot names.
    public let label: String

    /// A closure that patches `EnvironmentValues` before each view render.
    /// Runs on `@MainActor` because `EnvironmentValues` is a SwiftUI type.
    public let environmentPatch: @MainActor @Sendable (inout EnvironmentValues) -> Void

    /// Creates a flow configuration.
    ///
    /// - Parameters:
    ///   - label: An identifier for this configuration. Defaults to `""`.
    ///   - environmentPatch: A closure to customize the SwiftUI
    ///     environment for rendered views. Defaults to no-op.
    public init(
        label: String = "",
        environmentPatch: @escaping @MainActor @Sendable (inout EnvironmentValues) -> Void = {
            _ in
        }
    ) {
        self.label = label
        self.environmentPatch = environmentPatch
    }
}
