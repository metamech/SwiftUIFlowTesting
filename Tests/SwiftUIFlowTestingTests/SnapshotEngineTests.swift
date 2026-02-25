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
}
