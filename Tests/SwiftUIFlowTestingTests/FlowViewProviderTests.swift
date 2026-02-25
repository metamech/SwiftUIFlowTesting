import Foundation
import SwiftUI
import Testing

@testable import SwiftUIFlowTesting

/// A mock model that conforms to FlowViewProvider for testing.
@Observable
final class MockProviderModel: FlowViewProvider {
    var screen: String = "initial"

    func advance(to screen: String) {
        self.screen = screen
    }

    var flowBody: some View {
        Text(screen)
    }
}

@Suite("FlowViewProvider")
@MainActor
struct FlowViewProviderTests {

    @Test func testerCanBeConstructedWithoutViewBuilder() {
        let model = MockProviderModel()
        let tester = FlowTester(name: "provider", model: model)
            .step("initial") { _ in }

        #expect(tester.stepCount == 1)
        #expect(tester.stepNames == ["provider-initial"])
    }

    @Test func stepsExecuteAndRunUsingFlowBody() {
        let model = MockProviderModel()

        let results = FlowTester(model: model)
            .step("initial") { _ in }
            .step("advanced") { $0.advance(to: "next") }
            .run(snapshotMode: .disabled)

        #expect(results.count == 2)
        #expect(model.screen == "next")
    }

    @Test func snapshotsCaptureUsingFlowBody() {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FlowViewProviderTests")
            .appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(
            at: dir,
            withIntermediateDirectories: true
        )

        let model = MockProviderModel()
        let config = SnapshotConfiguration(record: true, snapshotDirectory: dir.path)

        let results = FlowTester(model: model)
            .step("snap") { _ in }
            .run(snapshotMode: .builtin(config))

        #expect(results[0].snapshotResult?.pngData != nil)
    }

    @Test func explicitViewBuilderStillWorksWithProvider() {
        let model = MockProviderModel()
        var customViewUsed = false

        FlowTester(model: model) { m in
            customViewUsed = true
            return Text("custom: \(m.screen)")
        }
        .step("check") { _ in }
        .run(snapshotMode: .disabled)

        #expect(customViewUsed)
    }
}
