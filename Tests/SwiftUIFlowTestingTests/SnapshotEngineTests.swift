import Foundation
import SwiftUI
import Testing

@testable import SwiftUIFlowTesting

@Suite("SnapshotEngine")
@MainActor
struct SnapshotEngineTests {

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

    @Test func renderProducesPNGData() {
        let config = SnapshotConfiguration(snapshotDirectory: makeTempDir())
        let engine = SnapshotEngine(
            configuration: config,
            filePath: #filePath,
            function: #function
        )
        let data = engine.render(view: Text("Hello"))
        #expect(data != nil)
        // PNG magic bytes
        if let data {
            #expect(data.count > 8)
            let pngSignature: [UInt8] = [0x89, 0x50, 0x4E, 0x47]
            let header = Array(data.prefix(4))
            #expect(header == pngSignature)
        }
    }

    @Test func firstRunRecordsNewReference() {
        let dir = makeTempDir()
        let config = SnapshotConfiguration(snapshotDirectory: dir)
        let engine = SnapshotEngine(
            configuration: config,
            filePath: #filePath,
            function: #function
        )
        let result = engine.capture(name: "first-run", view: Text("Hello"))
        guard case .newReference(let path) = result.status else {
            Issue.record("Expected newReference, got \(result.status)")
            return
        }
        #expect(path.contains("first-run.png"))
        #expect(result.pngData != nil)
        #expect(FileManager.default.fileExists(atPath: path))
    }

    @Test func secondRunMatches() {
        let dir = makeTempDir()
        let config = SnapshotConfiguration(snapshotDirectory: dir)
        let engine = SnapshotEngine(
            configuration: config,
            filePath: #filePath,
            function: #function
        )
        // First capture records reference
        _ = engine.capture(name: "match-test", view: Text("Stable"))
        // Second capture should match
        let result = engine.capture(name: "match-test", view: Text("Stable"))
        guard case .matched = result.status else {
            Issue.record("Expected matched, got \(result.status)")
            return
        }
        #expect(result.pngData != nil)
    }

    @Test func mismatchWritesFailFile() {
        let dir = makeTempDir()
        let config = SnapshotConfiguration(snapshotDirectory: dir)
        let engine = SnapshotEngine(
            configuration: config,
            filePath: #filePath,
            function: #function
        )
        // Record reference with one view
        _ = engine.capture(name: "mismatch-test", view: Text("Original"))
        // Capture with different view
        let result = engine.capture(name: "mismatch-test", view: Text("Different content here"))
        guard case .mismatch(let refPath, let actualPath) = result.status else {
            Issue.record("Expected mismatch, got \(result.status)")
            return
        }
        #expect(refPath.contains("mismatch-test.png"))
        #expect(actualPath.contains("mismatch-test.fail.png"))
        #expect(FileManager.default.fileExists(atPath: actualPath))
    }

    @Test func recordModeAlwaysOverwrites() {
        let dir = makeTempDir()
        let config = SnapshotConfiguration(record: true, snapshotDirectory: dir)
        let engine = SnapshotEngine(
            configuration: config,
            filePath: #filePath,
            function: #function
        )
        // First capture
        _ = engine.capture(name: "record-test", view: Text("V1"))
        // Second capture with different content in record mode
        let result = engine.capture(name: "record-test", view: Text("V2"))
        guard case .newReference = result.status else {
            Issue.record("Expected newReference in record mode, got \(result.status)")
            return
        }
    }

    @Test func snapshotDirectoryFromFilePath() {
        let config = SnapshotConfiguration()
        let engine = SnapshotEngine(
            configuration: config,
            filePath: "/path/to/MyTests/MyTestFile.swift",
            function: "testSomething()"
        )
        #expect(engine.snapshotDirectory.contains("__Snapshots__"))
        #expect(engine.snapshotDirectory.contains("MyTestFile"))
    }

    @Test func nameWithSlashIsSanitized() {
        let dir = makeTempDir()
        let config = SnapshotConfiguration(snapshotDirectory: dir)
        let engine = SnapshotEngine(
            configuration: config,
            filePath: #filePath,
            function: #function
        )
        let result = engine.capture(name: "flow/step", view: Text("Hi"))
        guard case .newReference(let path) = result.status else {
            Issue.record("Expected newReference, got \(result.status)")
            return
        }
        #expect(path.contains("flow_step.png"))
        #expect(!path.contains("flow/step"))
    }

    // MARK: - Tolerance Tests

    @Test func toleranceAllowsSlightDifference() {
        let dir = makeTempDir()
        // Record with a specific sRGB color
        let recordConfig = SnapshotConfiguration(
            record: true,
            tolerance: 0.1,
            snapshotDirectory: dir
        )
        let recordEngine = SnapshotEngine(
            configuration: recordConfig,
            filePath: #filePath,
            function: #function
        )
        let baseColor = Color(.sRGB, red: 0.8, green: 0.2, blue: 0.2)
        _ = recordEngine.capture(name: "tolerance-test", view: baseColor)

        // Compare with slightly-off color using tolerance
        let compareConfig = SnapshotConfiguration(
            tolerance: 0.1,
            snapshotDirectory: dir
        )
        let compareEngine = SnapshotEngine(
            configuration: compareConfig,
            filePath: #filePath,
            function: #function
        )
        let nearColor = Color(.sRGB, red: 0.82, green: 0.21, blue: 0.19)
        let result = compareEngine.capture(
            name: "tolerance-test",
            view: nearColor
        )
        guard case .matched = result.status else {
            Issue.record("Expected matched with tolerance, got \(result.status)")
            return
        }
    }

    @Test func zeroToleranceRejectsSlightDifference() {
        let dir = makeTempDir()
        // Record with a specific sRGB color
        let recordConfig = SnapshotConfiguration(
            record: true,
            snapshotDirectory: dir
        )
        let recordEngine = SnapshotEngine(
            configuration: recordConfig,
            filePath: #filePath,
            function: #function
        )
        let baseColor = Color(.sRGB, red: 0.8, green: 0.2, blue: 0.2)
        _ = recordEngine.capture(name: "zero-tol-test", view: baseColor)

        // Compare with slightly-off color at zero tolerance
        let compareConfig = SnapshotConfiguration(
            tolerance: 0.0,
            snapshotDirectory: dir
        )
        let compareEngine = SnapshotEngine(
            configuration: compareConfig,
            filePath: #filePath,
            function: #function
        )
        let nearColor = Color(.sRGB, red: 0.82, green: 0.21, blue: 0.19)
        let result = compareEngine.capture(
            name: "zero-tol-test",
            view: nearColor
        )
        guard case .mismatch = result.status else {
            Issue.record("Expected mismatch at zero tolerance, got \(result.status)")
            return
        }
    }

    // MARK: - Diff Image Tests

    @Test func mismatchWritesDiffFile() {
        let dir = makeTempDir()
        let config = SnapshotConfiguration(snapshotDirectory: dir)
        let engine = SnapshotEngine(
            configuration: config,
            filePath: #filePath,
            function: #function
        )
        _ = engine.capture(name: "diff-write", view: Text("Original"))
        _ = engine.capture(name: "diff-write", view: Text("Changed content"))
        let diffPath = URL(fileURLWithPath: dir)
            .appendingPathComponent("diff-write.diff.png").path
        #expect(FileManager.default.fileExists(atPath: diffPath))
    }

    @Test func diffResultIncludesDiffPath() {
        let dir = makeTempDir()
        let config = SnapshotConfiguration(snapshotDirectory: dir)
        let engine = SnapshotEngine(
            configuration: config,
            filePath: #filePath,
            function: #function
        )
        _ = engine.capture(name: "diff-path", view: Text("Original"))
        let result = engine.capture(name: "diff-path", view: Text("Changed content"))
        #expect(result.diffPath != nil)
        #expect(result.diffPath?.contains("diff-path.diff.png") == true)
    }

    // MARK: - Observable Mutation Tests

    @Test func observableMutationCapturedInSnapshot() {
        let dir = makeTempDir()
        let config = SnapshotConfiguration(record: true, snapshotDirectory: dir)
        let engine = SnapshotEngine(
            configuration: config,
            filePath: #filePath,
            function: #function
        )
        let model = MockModel()
        model.screen = "initial"
        _ = engine.capture(name: "observable-mutation", view: MockView(model: model))

        // Mutate the model and render a fresh view
        model.screen = "UPDATED"
        let result = engine.capture(name: "observable-mutation-after", view: MockView(model: model))
        guard case .newReference = result.status else {
            Issue.record("Expected newReference, got \(result.status)")
            return
        }

        // Now compare the two snapshots — they must differ
        let refPath = URL(fileURLWithPath: dir)
            .appendingPathComponent("observable-mutation.png")
        let afterPath = URL(fileURLWithPath: dir)
            .appendingPathComponent("observable-mutation-after.png")
        let refData = try? Data(contentsOf: refPath)
        let afterData = try? Data(contentsOf: afterPath)
        #expect(refData != nil)
        #expect(afterData != nil)
        if let refData, let afterData {
            #expect(refData != afterData, "Snapshot should capture updated state, not stale state")
        }
    }

    @Test func observableMutationMatchesAfterRerender() {
        let dir = makeTempDir()
        let model = MockModel()
        model.screen = "UPDATED"

        let recordConfig = SnapshotConfiguration(record: true, snapshotDirectory: dir)
        let recordEngine = SnapshotEngine(
            configuration: recordConfig,
            filePath: #filePath,
            function: #function
        )
        _ = recordEngine.capture(name: "observable-rerender", view: MockView(model: model))

        let compareConfig = SnapshotConfiguration(snapshotDirectory: dir)
        let compareEngine = SnapshotEngine(
            configuration: compareConfig,
            filePath: #filePath,
            function: #function
        )
        let result = compareEngine.capture(name: "observable-rerender", view: MockView(model: model))
        guard case .matched = result.status else {
            Issue.record("Expected matched after rerender, got \(result.status)")
            return
        }
    }

    @Test func matchCleansDiffFile() {
        let dir = makeTempDir()
        let diffURL = URL(fileURLWithPath: dir)
            .appendingPathComponent("clean-test.diff.png")
        // Plant a fake diff file
        try? FileManager.default.createDirectory(
            at: URL(fileURLWithPath: dir),
            withIntermediateDirectories: true
        )
        FileManager.default.createFile(
            atPath: diffURL.path,
            contents: Data([0x00])
        )
        #expect(FileManager.default.fileExists(atPath: diffURL.path))

        let config = SnapshotConfiguration(snapshotDirectory: dir)
        let engine = SnapshotEngine(
            configuration: config,
            filePath: #filePath,
            function: #function
        )
        // Record reference then match
        _ = engine.capture(name: "clean-test", view: Text("Same"))
        _ = engine.capture(name: "clean-test", view: Text("Same"))
        #expect(!FileManager.default.fileExists(atPath: diffURL.path))
    }
}
