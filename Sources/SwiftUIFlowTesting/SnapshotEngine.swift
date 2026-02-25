import Foundation
import SwiftUI

/// Internal engine that renders SwiftUI views to PNG and manages
/// reference image comparison on disk.
@MainActor
struct SnapshotEngine {
    let configuration: SnapshotConfiguration
    let snapshotDirectory: String

    init(configuration: SnapshotConfiguration, filePath: String, function: String) {
        self.configuration = configuration
        if let dir = configuration.snapshotDirectory {
            self.snapshotDirectory = dir
        } else {
            let fileURL = URL(fileURLWithPath: filePath)
            let directory = fileURL.deletingLastPathComponent()
            let testFileName = fileURL.deletingPathExtension().lastPathComponent
            self.snapshotDirectory =
                directory
                .appendingPathComponent("__Snapshots__")
                .appendingPathComponent(testFileName)
                .path
        }
    }

    // MARK: - Rendering

    func render<V: View>(view: V) -> Data? {
        let renderer = ImageRenderer(
            content: view.frame(
                width: configuration.proposedSize.width,
                height: configuration.proposedSize.height
            )
        )
        renderer.scale = configuration.scale

        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
            guard let nsImage = renderer.nsImage else { return nil }
            guard let tiffData = nsImage.tiffRepresentation else { return nil }
            guard let bitmap = NSBitmapImageRep(data: tiffData) else { return nil }
            return bitmap.representation(using: .png, properties: [:])
        #elseif canImport(UIKit)
            guard let uiImage = renderer.uiImage else { return nil }
            return uiImage.pngData()
        #else
            return nil
        #endif
    }

    // MARK: - Capture

    func capture(name: String, view: some View) -> SnapshotResult {
        guard let pngData = render(view: view) else {
            return SnapshotResult(status: .unavailable)
        }

        let dirURL = URL(fileURLWithPath: snapshotDirectory)
        let sanitizedName = name.replacingOccurrences(of: "/", with: "_")
        let referenceURL = dirURL.appendingPathComponent("\(sanitizedName).png")
        let failURL = dirURL.appendingPathComponent("\(sanitizedName).fail.png")

        // Ensure directory exists
        try? FileManager.default.createDirectory(
            at: dirURL,
            withIntermediateDirectories: true
        )

        // Record mode: always overwrite reference
        if configuration.record {
            try? pngData.write(to: referenceURL)
            // Clean up any previous failure artifact
            try? FileManager.default.removeItem(at: failURL)
            return SnapshotResult(
                status: .newReference(path: referenceURL.path),
                pngData: pngData
            )
        }

        // First run: no reference exists yet
        guard let referenceData = try? Data(contentsOf: referenceURL) else {
            try? pngData.write(to: referenceURL)
            return SnapshotResult(
                status: .newReference(path: referenceURL.path),
                pngData: pngData
            )
        }

        // Compare
        if referenceData == pngData {
            // Clean up any stale failure artifact
            try? FileManager.default.removeItem(at: failURL)
            return SnapshotResult(status: .matched, pngData: pngData)
        }

        // Mismatch: write the actual image as .fail.png
        try? pngData.write(to: failURL)
        return SnapshotResult(
            status: .mismatch(
                referencePath: referenceURL.path,
                actualPath: failURL.path
            ),
            pngData: pngData
        )
    }
}
