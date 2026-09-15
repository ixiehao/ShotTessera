import AppKit
import AVFoundation
import CoreGraphics
import Foundation
import Vision

final class VideoStoryboardAnalyzer: @unchecked Sendable {
    private let maximumSamples = 540

    func analyze(
        videoURL: URL,
        gridSide: Int,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws -> StoryboardResult {
        let asset = AVURLAsset(url: videoURL)
        let duration = try await asset.load(.duration).seconds
        guard duration.isFinite, duration > 0 else { throw StoryboardError.unreadableVideo }

        let targetCount = gridSide * gridSide
        let sampleCount = min(maximumSamples, max(targetCount * 5, 90))
        let interval = max(0.22, duration / Double(sampleCount))
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = CMTime(value: 1, timescale: 30)
        generator.requestedTimeToleranceAfter = CMTime(value: 1, timescale: 30)

        var descriptors: [FrameDescriptor] = []
        var index = 0
        var time = 0.0
        while time < duration {
            try Task.checkCancellation()
            defer { time += interval; index += 1 }
            guard let image = try? generator.copyCGImage(at: CMTime(seconds: time, preferredTimescale: 600), actualTime: nil) else {
                continue
            }
            let metrics = PixelMetrics.make(from: image)
            descriptors.append(FrameDescriptor(
                id: index,
                time: time,
                histogram: metrics.histogram,
                luminance: metrics.luminance,
                blackRatio: metrics.blackRatio,
                sharpness: metrics.sharpness,
                fingerprint: metrics.fingerprint
            ))
            progress(0.08 + 0.47 * min(1, time / duration))
        }

        guard !descriptors.isEmpty else { throw StoryboardError.unreadableVideo }

        // Score a timeline-distributed set rather than only sharp landscape shots,
        // so a dimmer but meaningful close-up still has an opportunity to win.
        let visionSampleCount = min(descriptors.count, max(180, targetCount * 4))
        let visionCandidates = FrameSelection.evenlySpaced(descriptors, count: visionSampleCount)
        var scoreByID: [Int: Float] = [:]
        for (offset, candidate) in visionCandidates.enumerated() {
            try Task.checkCancellation()
            guard let image = try? generator.copyCGImage(at: CMTime(seconds: candidate.time, preferredTimescale: 600), actualTime: nil) else {
                continue
            }
            scoreByID[candidate.id] = peopleScore(in: visionPreview(from: image))
            progress(0.55 + 0.09 * Double(offset + 1) / Double(visionCandidates.count))
        }
        descriptors = descriptors.map { descriptor in
            var updated = descriptor
            updated.peopleScore = scoreByID[descriptor.id] ?? 0
            return updated
        }
        progress(0.62)

        let selected = FrameSelection.chooseFrames(from: descriptors, count: targetCount)
        guard !selected.isEmpty else { throw StoryboardError.noUsableFrames }

        var captured: [CapturedFrame] = []
        for (offset, descriptor) in selected.enumerated() {
            try Task.checkCancellation()
            guard let image = try? generator.copyCGImage(at: CMTime(seconds: descriptor.time, preferredTimescale: 600), actualTime: nil),
                  let data = NSBitmapImageRep(cgImage: image).representation(using: .jpeg, properties: [.compressionFactor: 0.94])
            else { continue }
            captured.append(CapturedFrame(id: descriptor.id, time: descriptor.time, jpegData: data))
            progress(0.64 + 0.31 * Double(offset + 1) / Double(selected.count))
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
