#if canImport(SwiftData)
import SwiftData
import Testing

@testable import SwiftUIFlowTesting

// Tests for #1072 — SwiftData test context builder

@Suite(.serialized)
@MainActor
struct FlowTestContextTests {
    // A minimal SwiftData model for testing
    @Model
    final class TestItem {
        var name: String

        init(name: String) {
            self.name = name
        }
    }

    @Test
    func createInMemoryContext() throws {
        let context = try FlowTestContext(for: [TestItem.self])
        #expect(context.modelContainer !== nil as AnyObject?)
        #expect(context.modelContext !== nil as AnyObject?)
    }

    @Test
    func insertAndFetchInMemory() throws {
        let context = try FlowTestContext(for: [TestItem.self])

        let item = TestItem(name: "Test")
        context.modelContext.insert(item)
        try context.modelContext.save()

        let descriptor = FetchDescriptor<TestItem>()
        let items = try context.modelContext.fetch(descriptor)
        #expect(items.count == 1)
        #expect(items[0].name == "Test")
    }

    @Test
    func separateContextsAreIsolated() throws {
        let context1 = try FlowTestContext(for: [TestItem.self])
        let context2 = try FlowTestContext(for: [TestItem.self])

        let item = TestItem(name: "Only in context1")
        context1.modelContext.insert(item)
        try context1.modelContext.save()

        let descriptor = FetchDescriptor<TestItem>()
        let items1 = try context1.modelContext.fetch(descriptor)
        let items2 = try context2.modelContext.fetch(descriptor)

        #expect(items1.count == 1)
        #expect(items2.count == 0)
    }

    @Test
    func flowConfigurationWithModelContainer() throws {
        let context = try FlowTestContext(for: [TestItem.self])

        let config = FlowConfiguration.withModelContainer(context.modelContainer)
        #expect(config.label == "swiftdata")
    }

    @Test
    func flowConfigurationWithCustomLabel() throws {
        let context = try FlowTestContext(for: [TestItem.self])

        let config = FlowConfiguration.withModelContainer(
            context.modelContainer,
            label: "test-db"
        )
        #expect(config.label == "test-db")
    }
}
#endif
