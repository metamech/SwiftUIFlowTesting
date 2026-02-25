import Foundation
import SwiftUI
@_spi(Experimental) @testable import SwiftUIFlowTesting
import Testing

@Suite("FlowTester Snapshots")
@MainActor
struct FlowTesterSnapshotTests {

    private func makeTempDir() -> String {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("SwiftUIFlowTestingTests")
            .appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(
            at: dir,
            withIntermediateDirectories: true
        )
        return dir.path
    }

    // MARK: - Built-in Snapshot Mode

    @Test func runWithBuiltinSnapshotProducesResults() {
        let dir = makeTempDir()
        let model = MockModel()
        let config = SnapshotConfiguration(record: true, snapshotDirectory: dir)

        let results = FlowTester(model: model) { m in MockView(model: m) }
            .step("initial") { _ in }
            .step("advanced") { $0.advance(to: "next") }
            .run(snapshotMode: .builtin(config))

        #expect(results.count == 2)
        #expect(results[0].snapshotResult != nil)
        #expect(results[1].snapshotResult != nil)
        #expect(results[0].snapshotResult?.pngData != nil)
        #expect(results[1].snapshotResult?.pngData != nil)
    }

    @Test func runWithBuiltinSnapshotRecordsFiles() {
        let dir = makeTempDir()
        let model = MockModel()
        let config = SnapshotConfiguration(record: true, snapshotDirectory: dir)

        FlowTester(model: model) { m in MockView(model: m) }
            .step("screen1") { _ in }
            .run(snapshotMode: .builtin(config))

        let filePath = URL(fileURLWithPath: dir)
            .appendingPathComponent("screen1.png").path
        #expect(FileManager.default.fileExists(atPath: filePath))
    }

    // MARK: - Disabled Mode

    @Test func runWithDisabledSnapshotSkips() {
        let model = MockModel()

        let results = FlowTester(model: model) { m in MockView(model: m) }
            .step("skip") { _ in }
            .run(snapshotMode: .disabled)

        #expect(results.count == 1)
        #expect(results[0].snapshotResult == nil)
    }

    // MARK: - Custom Mode

    @Test func runWithCustomSnapshotCallsClosure() {
        let model = MockModel()
        var capturedNames: [String] = []

        let results = FlowTester(model: model) { m in MockView(model: m) }
            .step("custom-step") { _ in }
            .run(
                snapshotMode: .custom { name, _ in
                    capturedNames.append(name)
                }
            )

        #expect(capturedNames == ["custom-step"])
        #expect(results.count == 1)
        #expect(results[0].snapshotResult == nil)
    }

    // MARK: - Closure API Backward Compatibility

    @Test func closureRunHasNilSnapshotResult() {
        let model = MockModel()

        let results = FlowTester(model: model) { m in MockView(model: m) }
            .step("legacy") { _ in }
            .run { _, _ in }

        #expect(results.count == 1)
        #expect(results[0].snapshotResult == nil)
    }

    // MARK: - attachSnapshots

    @Test func attachSnapshotsCallsHandler() {
        let dir = makeTempDir()
        let model = MockModel()
        let config = SnapshotConfiguration(record: true, snapshotDirectory: dir)

        var attachments: [(Data, String)] = []

        FlowTester(model: model) { m in MockView(model: m) }
            .step("snap1") { _ in }
            .step("snap2") { $0.advance(to: "next") }
            .run(snapshotMode: .builtin(config))
            .attachSnapshots { data, name in
                attachments.append((data, name))
            }

        #expect(attachments.count == 2)
        #expect(attachments[0].1 == "snap1.png")
        #expect(attachments[1].1 == "snap2.png")
        #expect(!attachments[0].0.isEmpty)
    }

    @Test func attachSnapshotsSkipsNilResults() {
        let model = MockModel()
        var attachments: [(Data, String)] = []

        FlowTester(model: model) { m in MockView(model: m) }
            .step("no-snap") { _ in }
            .run(snapshotMode: .disabled)
            .attachSnapshots { data, name in
                attachments.append((data, name))
            }

        #expect(attachments.isEmpty)
    }

    // MARK: - Async Run with Built-in Snapshots

    @Test func asyncRunWithBuiltinSnapshot() async {
        let dir = makeTempDir()
        let model = MockModel()
        let config = SnapshotConfiguration(record: true, snapshotDirectory: dir)

        let results = await FlowTester(model: model) { m in MockView(model: m) }
            .asyncStep("async-snap") { $0.advance(to: "loaded") }
            .asyncRun(snapshotMode: .builtin(config))

        #expect(results.count == 1)
        #expect(results[0].snapshotResult != nil)
        #expect(results[0].snapshotResult?.pngData != nil)
    }

    // MARK: - Matrix Run with Built-in Snapshots

    @Test func matrixRunWithBuiltinSnapshot() {
        let dir = makeTempDir()
        let model = MockModel()
        let config = SnapshotConfiguration(record: true, snapshotDirectory: dir)

        let configs = [
            FlowConfiguration(label: "light") { _ in },
            FlowConfiguration(label: "dark") { env in env.colorScheme = .dark },
        ]

        let results = FlowTester(model: model) { m in MockView(model: m) }
            .step("screen") { _ in }
            .matrixRun(
                configurations: configs,
                modelFactory: { MockModel() },
                snapshotMode: .builtin(config)
            )

        #expect(results.count == 2)
        #expect(results[0].snapshotResult != nil)
        #expect(results[1].snapshotResult != nil)
        #expect(results[0].configurationLabel == "light")
        #expect(results[1].configurationLabel == "dark")
    }

    // MARK: - Per-Step Snapshot Skip

    @Test func stepWithSnapshotFalseReturnsSkipped() {
        let model = MockModel()

        let results = FlowTester(model: model) { m in MockView(model: m) }
            .step("skipped", snapshot: false) { _ in }
            .run(snapshotMode: .disabled)

        #expect(results.count == 1)
        guard case .skipped = results[0].snapshotResult?.status else {
            Issue.record("Expected .skipped status")
            return
        }
    }

    @Test func stepWithSnapshotFalseDoesNotWriteFile() {
        let dir = makeTempDir()
        let model = MockModel()
        let config = SnapshotConfiguration(record: true, snapshotDirectory: dir)

        FlowTester(model: model) { m in MockView(model: m) }
            .step("no-snap", snapshot: false) { _ in }
            .run(snapshotMode: .builtin(config))

        let filePath = URL(fileURLWithPath: dir)
            .appendingPathComponent("no-snap.png").path
        #expect(!FileManager.default.fileExists(atPath: filePath))
    }

    @Test func stepWithDefaultSnapshotTrueIsUnaffected() {
        let dir = makeTempDir()
        let model = MockModel()
        let config = SnapshotConfiguration(record: true, snapshotDirectory: dir)

        let results = FlowTester(model: model) { m in MockView(model: m) }
            .step("captured") { _ in }
            .run(snapshotMode: .builtin(config))

        #expect(results[0].snapshotResult?.pngData != nil)
        guard case .newReference = results[0].snapshotResult?.status else {
            Issue.record("Expected newReference for default snapshot: true")
            return
        }
    }

    @Test func mixedSnapshotSkipFlow() {
        let dir = makeTempDir()
        let model = MockModel()
        let config = SnapshotConfiguration(record: true, snapshotDirectory: dir)

        let results = FlowTester(model: model) { m in MockView(model: m) }
            .step("snap-0") { _ in }
            .step("skip-1", snapshot: false) { $0.advance(to: "next") }
            .step("snap-2") { _ in }
            .run(snapshotMode: .builtin(config))

        #expect(results.count == 3)
        // Steps 0 and 2 have snapshots
        #expect(results[0].snapshotResult?.pngData != nil)
        #expect(results[2].snapshotResult?.pngData != nil)
        // Step 1 is skipped
        guard case .skipped = results[1].snapshotResult?.status else {
            Issue.record("Expected .skipped for step 1")
            return
        }
        #expect(results[1].snapshotResult?.pngData == nil)

        // Only 2 files on disk
        let snap0 = URL(fileURLWithPath: dir).appendingPathComponent("snap-0.png").path
        let skip1 = URL(fileURLWithPath: dir).appendingPathComponent("skip-1.png").path
        let snap2 = URL(fileURLWithPath: dir).appendingPathComponent("snap-2.png").path
        #expect(FileManager.default.fileExists(atPath: snap0))
        #expect(!FileManager.default.fileExists(atPath: skip1))
        #expect(FileManager.default.fileExists(atPath: snap2))
    }

    @Test func attachSnapshotsSkipsSkippedResults() {
        let model = MockModel()
        var attachments: [(Data, String)] = []

        FlowTester(model: model) { m in MockView(model: m) }
            .step("has-snap") { _ in }
            .step("no-snap", snapshot: false) { _ in }
            .run(snapshotMode: .disabled)
            .attachSnapshots { data, name in
                attachments.append((data, name))
            }

        #expect(attachments.isEmpty)
    }

    // MARK: - Snapshot Result Status

    @Test func snapshotResultStatusNewThenMatch() {
        let dir = makeTempDir()
        let model = MockModel()
        let config = SnapshotConfiguration(snapshotDirectory: dir)

        // First run: new reference
        let results1 = FlowTester(model: model) { m in MockView(model: m) }
            .step("stable") { _ in }
            .run(snapshotMode: .builtin(config))

        guard case .newReference = results1[0].snapshotResult?.status else {
            Issue.record("Expected newReference on first run")
            return
        }

        // Second run with same view: match
        let model2 = MockModel()
        let results2 = FlowTester(model: model2) { m in MockView(model: m) }
            .step("stable") { _ in }
            .run(snapshotMode: .builtin(config))

        guard case .matched = results2[0].snapshotResult?.status else {
            Issue.record(
                "Expected matched on second run, got \(String(describing: results2[0].snapshotResult?.status))"
            )
            return
        }
    }
}
