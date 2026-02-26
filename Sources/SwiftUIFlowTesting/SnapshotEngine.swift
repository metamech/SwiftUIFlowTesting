import CoreGraphics
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
        let framedView = view.frame(
            width: configuration.proposedSize.width,
            height: configuration.proposedSize.height
        )

        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
            // Always use NSHostingView rendering on macOS. ImageRenderer
            // produces a yellow/red prohibition-symbol placeholder for
            // complex views (e.g. NavigationSplitView) in test bundles
            // that lack a full app environment, and it returns a non-nil
            // image so the fallback never triggers.
            return renderViaHostingView(view: framedView)
        #elseif canImport(UIKit)
            let renderer = ImageRenderer(content: framedView)
            renderer.scale = configuration.scale
            guard let uiImage = renderer.uiImage else { return nil }
            return uiImage.pngData()
        #else
            return nil
        #endif
    }

    #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        private func renderViaHostingView<V: View>(view: V) -> Data? {
            let hostingView = NSHostingView(rootView: view)
            let pointSize = NSSize(
                width: configuration.proposedSize.width,
                height: configuration.proposedSize.height
            )
            hostingView.frame = NSRect(origin: .zero, size: pointSize)

            let window = NSWindow(
                contentRect: NSRect(origin: .zero, size: pointSize),
                styleMask: .borderless,
                backing: .buffered,
                defer: false
            )
            window.contentView = hostingView
            hostingView.layoutSubtreeIfNeeded()
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.05))
            hostingView.layoutSubtreeIfNeeded()

            let scale = configuration.scale
            let pixelWidth = Int(pointSize.width * scale)
            let pixelHeight = Int(pointSize.height * scale)

            guard
                let bitmapRep = NSBitmapImageRep(
                    bitmapDataPlanes: nil,
                    pixelsWide: pixelWidth,
                    pixelsHigh: pixelHeight,
                    bitsPerSample: 8,
                    samplesPerPixel: 4,
                    hasAlpha: true,
                    isPlanar: false,
                    colorSpaceName: .deviceRGB,
                    bytesPerRow: pixelWidth * 4,
                    bitsPerPixel: 32
                )
            else {
                return nil
            }
            bitmapRep.size = pointSize

            guard let context = NSGraphicsContext(bitmapImageRep: bitmapRep) else {
                return nil
            }

            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = context
            hostingView.displayIgnoringOpacity(
                hostingView.bounds,
                in: context
            )
            NSGraphicsContext.restoreGraphicsState()

            return bitmapRep.representation(using: .png, properties: [:])
        }
    #endif

    // MARK: - Capture

    func capture(name: String, view: some View) -> SnapshotResult {
        guard let pngData = render(view: view) else {
            return SnapshotResult(status: .unavailable)
        }

        let dirURL = URL(fileURLWithPath: snapshotDirectory)
        let sanitizedName = name.replacingOccurrences(of: "/", with: "_")
        let referenceURL = dirURL.appendingPathComponent("\(sanitizedName).png")
        let failURL = dirURL.appendingPathComponent("\(sanitizedName).fail.png")
        let diffURL = dirURL.appendingPathComponent("\(sanitizedName).diff.png")

        // Ensure directory exists
        try? FileManager.default.createDirectory(
            at: dirURL,
            withIntermediateDirectories: true
        )

        // Record mode: always overwrite reference
        if configuration.record {
            try? pngData.write(to: referenceURL)
            // Clean up any previous failure/diff artifacts
            try? FileManager.default.removeItem(at: failURL)
            try? FileManager.default.removeItem(at: diffURL)
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
        if imagesMatch(
            referenceData: referenceData,
            actualData: pngData,
            tolerance: configuration.tolerance
        ) {
            // Clean up any stale failure/diff artifacts
            try? FileManager.default.removeItem(at: failURL)
            try? FileManager.default.removeItem(at: diffURL)
            return SnapshotResult(status: .matched, pngData: pngData)
        }

        // Mismatch: write the actual image as .fail.png
        try? pngData.write(to: failURL)

        // Generate diff image
        var diffPath: String?
        if let diffData = generateDiff(
            referenceData: referenceData,
            actualData: pngData
        ) {
            try? diffData.write(to: diffURL)
            diffPath = diffURL.path
        }

        return SnapshotResult(
            status: .mismatch(
                referencePath: referenceURL.path,
                actualPath: failURL.path
            ),
            pngData: pngData,
            diffPath: diffPath
        )
    }

    // MARK: - Pixel Comparison

    private func imagesMatch(
        referenceData: Data,
        actualData: Data,
        tolerance: Float
    ) -> Bool {
        // Fast path: binary equality
        if referenceData == actualData { return true }
        guard tolerance > 0 else { return false }

        guard
            let refImage = cgImage(from: referenceData),
            let actImage = cgImage(from: actualData)
        else {
            return false
        }

        // Dimension mismatch always fails
        if refImage.width != actImage.width || refImage.height != actImage.height {
            return false
        }

        return pixelCompare(refImage, actImage, tolerance: tolerance)
    }

    private func cgImage(from data: Data) -> CGImage? {
        guard
            let provider = CGDataProvider(data: data as CFData),
            let image = CGImage(
                pngDataProviderSource: provider,
                decode: nil,
                shouldInterpolate: false,
                intent: .defaultIntent
            )
        else {
            return nil
        }
        return image
    }

    private func pixelCompare(
        _ image1: CGImage,
        _ image2: CGImage,
        tolerance: Float
    ) -> Bool {
        let width = image1.width
        let height = image1.height
        let bytesPerRow = width * 4
        let totalBytes = bytesPerRow * height

        guard
            let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
            let context1 = CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ),
            let context2 = CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
        else {
            return false
        }

        let rect = CGRect(x: 0, y: 0, width: width, height: height)
        context1.draw(image1, in: rect)
        context2.draw(image2, in: rect)

        guard
            let data1 = context1.data,
            let data2 = context2.data
        else {
            return false
        }

        let ptr1 = data1.bindMemory(to: UInt8.self, capacity: totalBytes)
        let ptr2 = data2.bindMemory(to: UInt8.self, capacity: totalBytes)
        let threshold = tolerance * 255.0

        for i in 0..<totalBytes {
            let diff = abs(Float(ptr1[i]) - Float(ptr2[i]))
            if diff > threshold { return false }
        }

        return true
    }

    // MARK: - Diff Image

    private func generateDiff(referenceData: Data, actualData: Data) -> Data? {
        guard
            let refImage = cgImage(from: referenceData),
            let actImage = cgImage(from: actualData)
        else {
            return nil
        }

        let width = max(refImage.width, actImage.width)
        let height = max(refImage.height, actImage.height)
        let bytesPerRow = width * 4
        let totalBytes = bytesPerRow * height

        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else {
            return nil
        }

        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue

        // Draw both images into RGBA buffers
        guard
            let ctx1 = CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: bitmapInfo
            ),
            let ctx2 = CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: bitmapInfo
            ),
            let ctxOut = CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: bitmapInfo
            )
        else {
            return nil
        }

        let rect1 = CGRect(x: 0, y: 0, width: refImage.width, height: refImage.height)
        let rect2 = CGRect(x: 0, y: 0, width: actImage.width, height: actImage.height)
        ctx1.draw(refImage, in: rect1)
        ctx2.draw(actImage, in: rect2)

        guard
            let data1 = ctx1.data,
            let data2 = ctx2.data,
            let dataOut = ctxOut.data
        else {
            return nil
        }

        let ptr1 = data1.bindMemory(to: UInt8.self, capacity: totalBytes)
        let ptr2 = data2.bindMemory(to: UInt8.self, capacity: totalBytes)
        let ptrOut = dataOut.bindMemory(to: UInt8.self, capacity: totalBytes)

        let pixelCount = width * height
        for p in 0..<pixelCount {
            let offset = p * 4
            let r1 = ptr1[offset]
            let g1 = ptr1[offset + 1]
            let b1 = ptr1[offset + 2]
            let r2 = ptr2[offset]
            let g2 = ptr2[offset + 1]
            let b2 = ptr2[offset + 2]

            let differs =
                r1 != r2 || g1 != g2 || b1 != b2
                || ptr1[offset + 3] != ptr2[offset + 3]

            if differs {
                // Red highlight for differing pixels
                ptrOut[offset] = 255
                ptrOut[offset + 1] = 0
                ptrOut[offset + 2] = 0
                ptrOut[offset + 3] = 255
            } else {
                // Faded grayscale of original for matching pixels
                let gray = UInt8(
                    (UInt16(r1) + UInt16(g1) + UInt16(b1)) / 3
                )
                ptrOut[offset] = gray
                ptrOut[offset + 1] = gray
                ptrOut[offset + 2] = gray
                ptrOut[offset + 3] = 128
            }
        }

        guard let diffImage = ctxOut.makeImage() else { return nil }

        let mutableData = NSMutableData()
        guard
            let destination = CGImageDestinationCreateWithData(
                mutableData as CFMutableData,
                "public.png" as CFString,
                1,
                nil
            )
        else {
            return nil
        }
        CGImageDestinationAddImage(destination, diffImage, nil)
        guard CGImageDestinationFinalize(destination) else { return nil }

        return mutableData as Data
    }
}
