#if canImport(SwiftData)
import SwiftData
import SwiftUI

/// A convenience wrapper for creating in-memory SwiftData containers in flow tests.
///
/// `FlowTestContext` creates a `ModelContainer` configured with `isStoredInMemoryOnly = true`,
/// making it suitable for unit and flow tests that need SwiftData without touching disk.
///
/// Example:
/// ```swift
/// let context = try FlowTestContext(for: [Item.self, Tag.self])
/// let item = Item(name: "Test")
/// context.modelContext.insert(item)
/// try context.modelContext.save()
/// ```
@MainActor
public struct FlowTestContext: Sendable {
    /// The in-memory model container.
    public let modelContainer: ModelContainer

    /// A convenience accessor for the container's main context.
    public let modelContext: ModelContext

    /// Creates an in-memory test context for the given model types.
    ///
    /// - Parameter types: The `PersistentModel` types to include in the schema.
    /// - Throws: If the `ModelContainer` cannot be created.
    public init(for types: [any PersistentModel.Type]) throws {
        let schema = Schema(types)
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        self.modelContainer = try ModelContainer(for: schema, configurations: [config])
        self.modelContext = modelContainer.mainContext
    }
}

extension FlowConfiguration {
    /// Creates a flow configuration that injects the given model container
    /// into the SwiftUI environment.
    ///
    /// - Parameters:
    ///   - container: The `ModelContainer` to inject.
    ///   - label: An optional configuration label. Defaults to `"swiftdata"`.
    /// - Returns: A `FlowConfiguration` with the container set in the environment.
    public static func withModelContainer(
        _ container: ModelContainer,
        label: String = "swiftdata"
    ) -> FlowConfiguration {
        FlowConfiguration(label: label) { env in
            env.modelContext = container.mainContext
        }
    }
}
#endif
