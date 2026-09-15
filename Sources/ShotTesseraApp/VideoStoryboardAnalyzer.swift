import AppKit
import AVFoundation
import CoreGraphics
import Foundation
import Vision

final class VideoStoryboardAnalyzer: @unchecked Sendable {
    // The analysis thumbnail is also the storyboard source. Reusing it avoids a
    // second random-access decode pass after selection, which is the slowest part
    // of many H.264/HEVC files.
    private let maximumAnalysisSamples = 180
    private let minimumAnalysisEdge: CGFloat = 480
    private let maximumAnalysisEdge: CGFloat = 1280
    private let maximumVisionCandidates = 42

    func analyze(
        videoURL: URL,
        gridSide: Int,
        outputWidth: Int,
        progress: @escaping @Sendable (Double) -> Void,
        onPreviewFrame: @escaping @Sendable (CapturedFrame, Int, Int) -> Void
    ) async throws -> StoryboardResult {
        let asset = AVURLAsset(url: videoURL)
        let duration = try await asset.load(.duration).seconds
        guard duration.isFinite, duration > 0 else { throw StoryboardError.unreadableVideo }

        let targetCount = gridSide * gridSide
        let sampleCount = min(maximumAnalysisSamples, max(targetCount * 2, 72))
        let interval = max(0.22, duration / Double(sampleCount))
        let analysisGenerator = imageGenerator(
            asset: asset,
            maximumEdge: analysisMaximumEdge(gridSide: gridSide, outputWidth: outputWidth)
        )

        var descriptors: [FrameDescriptor] = []
        var index = 0
        var time = 0.0
        while time < duration {
            try Task.checkCancellation()
            defer { time += interval; index += 1 }
            guard let image = try? analysisGenerator.copyCGImage(at: CMTime(seconds: time, preferredTimescale: 600), actualTime: nil) else {
                continue
            }
            guard let previewData = jpegData(from: image) else { continue }
            let metrics = PixelMetrics.make(from: image)
            descriptors.append(FrameDescriptor(
                id: index,
                time: time,
                histogram: metrics.histogram,
                luminance: metrics.luminance,
                blackRatio: metrics.blackRatio,
                sharpness: metrics.sharpness,
                fingerprint: metrics.fingerprint,
                previewData: previewData
            ))
            progress(0.05 + 0.53 * min(1, time / duration))
        }

        guard !descriptors.isEmpty else { throw StoryboardError.unreadableVideo }

        // Vision is comparatively expensive. Score a compact blend of distributed
        // and high-quality candidates instead of inspecting the entire timeline.
        let visionSampleCount = min(
            descriptors.count,
            min(maximumVisionCandidates, max(18, targetCount / 2))
        )
        let visionCandidates = peopleCandidates(from: descriptors, count: visionSampleCount)
        var scoreByID: [Int: Float] = [:]
        for (offset, candidate) in visionCandidates.enumerated() {
            try Task.checkCancellation()
            guard let image = cgImage(from: candidate.previewData) else {
                continue
            }
            scoreByID[candidate.id] = peopleScore(in: visionPreview(from: image))
            progress(0.58 + 0.14 * Double(offset + 1) / Double(visionCandidates.count))
        }
        descriptors = descriptors.map { descriptor in
            var updated = descriptor
            updated.peopleScore = scoreByID[descriptor.id] ?? 0
            return updated
        }
        progress(0.72)

        let selected = FrameSelection.chooseFrames(from: descriptors, count: targetCount)
        guard !selected.isEmpty else { throw StoryboardError.noUsableFrames }

        var captured: [CapturedFrame] = []
        for (offset, descriptor) in selected.enumerated() {
            try Task.checkCancellation()
            guard let data = descriptor.previewData else { continue }
            let frame = CapturedFrame(id: descriptor.id, time: descriptor.time, jpegData: data)
            captured.append(frame)
            onPreviewFrame(frame, captured.count, selected.count)
            progress(0.72 + 0.26 * Double(offset + 1) / Double(selected.count))
            // Keep the preview visibly progressive without adding a perceptible
            // wait: 0.7 seconds or less for a full grid.
            let revealDelay = UInt64(max(12, min(45, 720 / max(1, selected.count)))) * 1_000_000
            try await Task.sleep(nanoseconds: revealDelay)
        }

        guard !captured.isEmpty else { throw StoryboardError.noUsableFrames }
        // Decoders occasionally reject an isolated timestamp in a damaged or VFR
        // file. Preserve a complete requested grid instead of rendering blank cards.
        if captured.count < targetCount {
            let fallback = captured
            var nextID = -1
            while captured.count < targetCount {
                let source = fallback[captured.count % fallback.count]
                captured.append(CapturedFrame(id: nextID, time: source.time, jpegData: source.jpegData))
                nextID -= 1
            }
        }
        progress(1)
        return StoryboardResult(frames: captured, sourceURL: videoURL)
    }

    private func imageGenerator(asset: AVAsset, maximumEdge: CGFloat) -> AVAssetImageGenerator {
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: maximumEdge, height: maximumEdge)
        // A small keyframe tolerance avoids expensive exact-frame seeks during
        // analysis, without noticeably changing a representative storyboard shot.
        let tolerance = CMTime(seconds: 0.75, preferredTimescale: 600)
        generator.requestedTimeToleranceBefore = tolerance
        generator.requestedTimeToleranceAfter = tolerance
        return generator
    }

    private func analysisMaximumEdge(gridSide: Int, outputWidth: Int) -> CGFloat {
        let estimatedCellWidth = Double(max(1920, outputWidth)) / Double(gridSide)
        let desiredEdge = CGFloat(estimatedCellWidth * 1.15)
        return min(maximumAnalysisEdge, max(minimumAnalysisEdge, desiredEdge))
    }

    private func jpegData(from image: CGImage) -> Data? {
        NSBitmapImageRep(cgImage: image).representation(using: .jpeg, properties: [.compressionFactor: 0.90])
    }

    private func cgImage(from data: Data?) -> CGImage? {
        guard let data, let image = NSImage(data: data) else { return nil }
        return image.cgImage(forProposedRect: nil, context: nil, hints: nil)
    }

    private func peopleCandidates(from descriptors: [FrameDescriptor], count: Int) -> [FrameDescriptor] {
        let usable = descriptors.filter(\.isUsable)
        guard !usable.isEmpty, count > 0 else { return [] }
        let distributed = FrameSelection.evenlySpaced(usable, count: max(1, count / 2))
        let visualLeaders = usable.sorted { $0.qualityScore > $1.qualityScore }
        var seen = Set<Int>()
        var candidates: [FrameDescriptor] = []
        for candidate in distributed + visualLeaders where candidates.count < count {
            if seen.insert(candidate.id).inserted {
                candidates.append(candidate)
            }
        }
        return candidates
    }

    private func peopleScore(in image: CGImage) -> Float {
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        let faces = VNDetectFaceRectanglesRequest()
        let bodies = VNDetectHumanRectanglesRequest()
        bodies.upperBodyOnly = false
        guard (try? handler.perform([faces, bodies])) != nil else { return 0 }

        let faceArea = (faces.results ?? [])
            .map { Float($0.boundingBox.width * $0.boundingBox.height) }
            .max() ?? 0
        let bodyArea = (bodies.results ?? [])
            .map { Float($0.boundingBox.width * $0.boundingBox.height) }
            .max() ?? 0

        // A clear close-up is useful, while a large human rectangle favors full-body shots.
        let faceScore = min(1, faceArea * 10)
        let bodyScore = min(1, bodyArea * 4)
        return max(faceScore * 0.9, bodyScore)
    }

    private func visionPreview(from image: CGImage) -> CGImage {
        let maxEdge: CGFloat = 540
        let longestEdge = max(CGFloat(image.width), CGFloat(image.height))
        guard longestEdge > maxEdge else { return image }
        let scale = maxEdge / longestEdge
        let width = max(1, Int(CGFloat(image.width) * scale))
        let height = max(1, Int(CGFloat(image.height) * scale))
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return image }
        context.interpolationQuality = .medium
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage() ?? image
    }
}

private struct PixelMetrics {
    let histogram: [Float]
    let luminance: Float
    let blackRatio: Float
    let sharpness: Float
    let fingerprint: UInt64

    static func make(from image: CGImage) -> PixelMetrics {
        let size = 48
        var bytes = [UInt8](repeating: 0, count: size * size * 4)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: &bytes,
            width: size,
            height: size,
            bitsPerComponent: 8,
            bytesPerRow: size * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return PixelMetrics(histogram: Array(repeating: 0, count: 16), luminance: 0, blackRatio: 1, sharpness: 0, fingerprint: 0)
        }

        context.interpolationQuality = .medium
        context.draw(image, in: CGRect(x: 0, y: 0, width: size, height: size))

        var luminance = [Float](repeating: 0, count: size * size)
        var histogram = [Float](repeating: 0, count: 16)
        var blackPixels = 0
        var sum: Float = 0
        for pixel in 0..<(size * size) {
            let offset = pixel * 4
            let value = (0.2126 * Float(bytes[offset]) + 0.7152 * Float(bytes[offset + 1]) + 0.0722 * Float(bytes[offset + 2])) / 255
            luminance[pixel] = value
            sum += value
            if value < 0.055 { blackPixels += 1 }
            histogram[min(15, Int(value * 16))] += 1
        }
        histogram = histogram.map { $0 / Float(size * size) }

        var edgeEnergy: Float = 0
        for y in 1..<(size - 1) {
            for x in 1..<(size - 1) {
                let center = luminance[y * size + x]
                let laplacian = abs(4 * center - luminance[y * size + x - 1] - luminance[y * size + x + 1] - luminance[(y - 1) * size + x] - luminance[(y + 1) * size + x])
                edgeEnergy += laplacian
            }
        }

        let average = sum / Float(size * size)
        let fingerprint = averageHash(luminance)
        return PixelMetrics(
            histogram: histogram,
            luminance: average,
            blackRatio: Float(blackPixels) / Float(size * size),
            sharpness: edgeEnergy / Float((size - 2) * (size - 2)),
            fingerprint: fingerprint
        )
    }

    private static func averageHash(_ luminance: [Float]) -> UInt64 {
        let sourceSize = 48
        let hashSize = 8
        var reduced = [Float](repeating: 0, count: hashSize * hashSize)
        for y in 0..<hashSize {
            for x in 0..<hashSize {
                var sum: Float = 0
                for sourceY in (y * 6)..<((y + 1) * 6) {
                    for sourceX in (x * 6)..<((x + 1) * 6) {
                        sum += luminance[sourceY * sourceSize + sourceX]
                    }
                }
                reduced[y * hashSize + x] = sum / 36
            }
        }
        let mean = reduced.reduce(0, +) / Float(reduced.count)
        return reduced.enumerated().reduce(into: UInt64(0)) { hash, element in
            if element.element >= mean { hash |= UInt64(1) << UInt64(element.offset) }
        }
    }
}
