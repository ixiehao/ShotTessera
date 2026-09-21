import AVFoundation
import CoreGraphics
import Foundation
import Vision

/// Stateless analysis worker. Keeping this as a value type lets Swift verify
/// that it is safe to pass into the detached generation task.
struct VideoStoryboardAnalyzer: Sendable {
    // The analysis thumbnail is also the storyboard source. Reusing it avoids a
    // second random-access decode pass after selection, which is the slowest part
    // of many H.264/HEVC files.
    private let maximumAnalysisSamples = 144
    private let minimumAnalysisEdge: CGFloat = 480
    private let maximumAnalysisEdge: CGFloat = 1280
    private let maximumVisionCandidates = 32

    func analyze(
        videoURL: URL,
        gridSide: Int,
        outputWidth: Int,
        progress: @escaping @Sendable (Double) -> Void,
        onPreviewFrame: @escaping @Sendable (CapturedFrame, Int, Int) -> Void
    ) async throws -> StoryboardResult {
        let asset = AVURLAsset(url: videoURL)
        let isPlayable = try await asset.load(.isPlayable)
        guard isPlayable else { throw StoryboardError.unsupportedCodec }
        let duration = try await asset.load(.duration).seconds
        guard duration.isFinite, duration > 0 else { throw StoryboardError.unreadableVideo }

        let targetCount = gridSide * gridSide
        let requestedSamples = max(48, Int((Double(targetCount) * 1.5).rounded(.up)))
        let sampleCount = min(maximumAnalysisSamples, requestedSamples)
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
            // Image decoding and metric buffers can accumulate across a long
            // batch. Keep each pass scoped so memory remains stable on both
            // Intel and Apple Silicon Macs.
            let descriptor: FrameDescriptor? = autoreleasepool {
                var actualTime = CMTime.zero
                guard let image = try? analysisGenerator.copyCGImage(
                    at: CMTime(seconds: time, preferredTimescale: 600),
                    actualTime: &actualTime
                ), let previewData = ImageCodec.jpegData(from: image, compressionQuality: 0.88) else {
                    return nil
                }
                let metrics = PixelMetrics.make(from: image)
                var descriptor = FrameDescriptor(
                    id: index,
                    time: actualTime.isValid && actualTime.seconds.isFinite ? actualTime.seconds : time,
                    histogram: metrics.histogram,
                    luminance: metrics.luminance,
                    blackRatio: metrics.blackRatio,
                    brightRatio: metrics.brightRatio,
                    dominantToneRatio: metrics.dominantToneRatio,
                    sharpness: metrics.sharpness,
                    fingerprint: metrics.fingerprint,
                    previewData: previewData
                )
                descriptor.aspectRatio = image.height > 0 ? Double(image.width) / Double(image.height) : (16.0 / 9.0)
                return descriptor
            }
            guard let descriptor else { continue }
            descriptors.append(descriptor)
            progress(0.05 + 0.53 * min(1, time / duration))
        }

        guard !descriptors.isEmpty else { throw StoryboardError.unreadableVideo }
        descriptors = addingTemporalSignals(to: descriptors)

        // Vision is comparatively expensive. Score a compact blend of distributed
        // and high-quality candidates instead of inspecting the entire timeline.
        let visionSampleCount = min(
            descriptors.count,
            min(maximumVisionCandidates, max(16, targetCount * 2))
        )
        let visionCandidates = peopleCandidates(from: descriptors, count: visionSampleCount)
        var peopleSignalsByID: [Int: PersonSignals] = [:]
        var textScoreByID: [Int: Float] = [:]
        for (offset, candidate) in visionCandidates.enumerated() {
            try Task.checkCancellation()
            let scores: (people: PersonSignals, text: Float)? = autoreleasepool {
                guard let data = candidate.previewData, let image = ImageCodec.cgImage(from: data) else { return nil }
                let preview = visionPreview(from: image)
                return (personSignals(in: preview), textOverlayScore(in: preview))
            }
            if let scores {
                peopleSignalsByID[candidate.id] = scores.people
                textScoreByID[candidate.id] = scores.text
            }
            progress(0.58 + 0.14 * Double(offset + 1) / Double(visionCandidates.count))
        }
        descriptors = descriptors.map { descriptor in
            var updated = descriptor
            let signals = peopleSignalsByID[descriptor.id] ?? PersonSignals()
            updated.peopleScore = signals.score
            updated.faceScore = signals.faceScore
            updated.bodyScore = signals.bodyScore
            updated.faceCount = signals.faceCount
            updated.textOverlayScore = textScoreByID[descriptor.id] ?? 0
            return updated
        }
        progress(0.72)

        let selected = FrameSelection.chooseFrames(from: descriptors, count: targetCount)
        guard !selected.isEmpty else { throw StoryboardError.noUsableFrames }

        var captured: [CapturedFrame] = []
        let finalFrameEdge = analysisMaximumEdge(gridSide: gridSide, outputWidth: outputWidth)
        for (offset, descriptor) in selected.enumerated() {
            try Task.checkCancellation()
            guard let data = descriptor.previewData else { continue }
            let fallback = CapturedFrame(
                id: descriptor.id,
                time: descriptor.time,
                jpegData: data,
                aspectRatio: descriptor.aspectRatio
            )
            // The broad scan above deliberately favors speed. Before committing
            // each final tile, make a precise +/- 3-frame comparison so motion
            // blur does not become the image exported to the storyboard.
            let frame: CapturedFrame
            do {
                frame = try await ManualFrameExtractor.captureSharpestFrame(
                    from: asset,
                    duration: duration,
                    at: descriptor.time,
                    identifier: descriptor.id,
                    maximumEdge: finalFrameEdge,
                    compressionQuality: 0.92
                )
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                // A corrupted timestamp must not blank an otherwise usable
                // storyboard tile; retain the analysis thumbnail as a fallback.
                frame = fallback
            }
            captured.append(frame)
            onPreviewFrame(frame, captured.count, selected.count)
            progress(0.72 + 0.26 * Double(offset + 1) / Double(selected.count))
            // Yield so the main actor can present progressive cards, but do not
            // add an artificial half-second delay to every video in a batch.
            await Task.yield()
        }

        guard !captured.isEmpty else { throw StoryboardError.noUsableFrames }
        // Decoders occasionally reject an isolated timestamp in a damaged or VFR
        // file. Preserve a complete requested grid instead of rendering blank cards.
        if captured.count < targetCount {
            let fallback = captured
            var nextID = -1
            while captured.count < targetCount {
                let source = fallback[captured.count % fallback.count]
                captured.append(CapturedFrame(id: nextID, time: source.time, jpegData: source.jpegData, aspectRatio: source.aspectRatio))
                nextID -= 1
            }
        }
        progress(1)
        return StoryboardResult(frames: captured, sourceURL: videoURL, duration: duration)
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

    private func peopleCandidates(from descriptors: [FrameDescriptor], count: Int) -> [FrameDescriptor] {
        let usable = descriptors.filter(\.isUsable)
        guard !usable.isEmpty, count > 0 else { return [] }
        // Opening/closing cards often occupy several consecutive samples. Always
        // inspect the first and last moments rather than relying solely on a
        // broad evenly-spaced pass, which could otherwise miss a 0s/19s intro.
        let boundaryCount = min(3, usable.count)
        let boundaries = Array(usable.prefix(boundaryCount)) + Array(usable.suffix(boundaryCount))
        let shotLeaders = FrameSelection.sceneRanges(in: usable).compactMap { range in
            usable[range].max { $0.qualityScore < $1.qualityScore }
        }
        let distributed = FrameSelection.evenlySpaced(usable, count: max(1, count / 4))
        let visualLeaders = usable.sorted { $0.qualityScore > $1.qualityScore }
        var seen = Set<Int>()
        var candidates: [FrameDescriptor] = []
        for candidate in boundaries + shotLeaders + distributed + visualLeaders where candidates.count < count {
            if seen.insert(candidate.id).inserted {
                candidates.append(candidate)
            }
        }
        return candidates
    }

    private struct PersonSignals: Sendable {
        var score: Float = 0
        var faceScore: Float = 0
        var bodyScore: Float = 0
        var faceCount = 0
    }

    private func personSignals(in image: CGImage) -> PersonSignals {
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        let faces = VNDetectFaceRectanglesRequest()
        guard (try? handler.perform([faces])) != nil else { return PersonSignals() }
        let detectedFaces = faces.results ?? []
        let faceArea = detectedFaces
            .map { Float($0.boundingBox.width * $0.boundingBox.height) }
            .max() ?? 0
        let faceScore = min(1, faceArea * 11)

        let bodies = VNDetectHumanRectanglesRequest()
        bodies.upperBodyOnly = false
        guard (try? handler.perform([bodies])) != nil else {
            return PersonSignals(score: faceScore * 0.92, faceScore: faceScore, bodyScore: 0, faceCount: detectedFaces.count)
        }
        let bodyArea = (bodies.results ?? [])
            .map { Float($0.boundingBox.width * $0.boundingBox.height) }
            .max() ?? 0

        // A clear close-up is useful, while a large human rectangle favors a
        // readable pose. Multiple faces are a strong dialogue/interaction cue.
        let bodyScore = min(1, bodyArea * 4)
        let interaction: Float = detectedFaces.count >= 2 ? min(0.30, Float(detectedFaces.count - 1) * 0.12) : 0
        return PersonSignals(
            score: min(1, max(faceScore * 0.92, bodyScore * 0.78) + interaction),
            faceScore: faceScore,
            bodyScore: bodyScore,
            faceCount: detectedFaces.count
        )
    }

    private func addingTemporalSignals(to descriptors: [FrameDescriptor]) -> [FrameDescriptor] {
        guard descriptors.count > 1 else { return descriptors }
        return descriptors.indices.map { index in
            var descriptor = descriptors[index]
            let previous = index > 0 ? FrameSelection.histogramDistance(descriptors[index - 1].histogram, descriptor.histogram) : 0
            let next = index + 1 < descriptors.count ? FrameSelection.histogramDistance(descriptor.histogram, descriptors[index + 1].histogram) : 0
            descriptor.motionScore = min(1, (previous + next) / 0.28)
            // A severe discontinuity is a cut or fade; it should never be the
            // preferred still even if its histogram happens to be high contrast.
            descriptor.transitionScore = max(previous, next) >= 0.52 ? 1 : max(0, max(previous, next) - 0.30) / 0.22
            return descriptor
        }
    }

    private func textOverlayScore(in image: CGImage) -> Float {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .fast
        request.usesLanguageCorrection = false
        request.minimumTextHeight = 0.018
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        guard (try? handler.perform([request])) != nil else { return 0 }
        let textRegions = (request.results ?? []).filter { !$0.topCandidates(1).isEmpty }
        guard !textRegions.isEmpty else { return 0 }
        let area = textRegions.reduce(Float(0)) { partial, observation in
            partial + Float(observation.boundingBox.width * observation.boundingBox.height)
        }
        // One large title or several warning lines are meaningful. A normal
        // one-line subtitle remains below the rejection threshold.
        return min(1, area * 4 + Float(textRegions.count) * 0.10)
    }

    private func visionPreview(from image: CGImage) -> CGImage {
        let maxEdge: CGFloat = 400
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

/// Compact visual metrics shared by automatic analysis and manual candidate
/// selection. They remain low-resolution so interactive selection stays fast.
struct PixelMetrics {
    let histogram: [Float]
    let luminance: Float
    let blackRatio: Float
    let brightRatio: Float
    let dominantToneRatio: Float
    let sharpness: Float
    /// Dissolves and motion trails have lots of weak edges; this tells them
    /// apart from decisive, in-focus boundaries.
    let focusedEdgeRatio: Float
    /// A secondary cue for washed-out dissolves and flash frames.
    let contrast: Float
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
            return PixelMetrics(
                histogram: Array(repeating: 0, count: 16),
                luminance: 0,
                blackRatio: 1,
                brightRatio: 0,
                dominantToneRatio: 1,
                sharpness: 0,
                focusedEdgeRatio: 0,
                contrast: 0,
                fingerprint: 0
            )
        }

        context.interpolationQuality = .medium
        context.draw(image, in: CGRect(x: 0, y: 0, width: size, height: size))

        var luminance = [Float](repeating: 0, count: size * size)
        var histogram = [Float](repeating: 0, count: 16)
        var blackPixels = 0
        var brightPixels = 0
        var sum: Float = 0
        for pixel in 0..<(size * size) {
            let offset = pixel * 4
            let value = (0.2126 * Float(bytes[offset]) + 0.7152 * Float(bytes[offset + 1]) + 0.0722 * Float(bytes[offset + 2])) / 255
            luminance[pixel] = value
            sum += value
            if value < 0.055 { blackPixels += 1 }
            if value > 0.92 { brightPixels += 1 }
            histogram[min(15, Int(value * 16))] += 1
        }
        histogram = histogram.map { $0 / Float(size * size) }

        var edgeEnergy: Float = 0
        var focusedEdgeEnergy: Float = 0
        for y in 1..<(size - 1) {
            for x in 1..<(size - 1) {
                let center = luminance[y * size + x]
                let laplacian = abs(4 * center - luminance[y * size + x - 1] - luminance[y * size + x + 1] - luminance[(y - 1) * size + x] - luminance[(y + 1) * size + x])
                edgeEnergy += laplacian
                if laplacian >= 0.18 { focusedEdgeEnergy += laplacian }
            }
        }

        let average = sum / Float(size * size)
        let variance = luminance.reduce(Float.zero) { partial, value in
            let delta = value - average
            return partial + delta * delta
        } / Float(size * size)
        let fingerprint = averageHash(luminance)
        return PixelMetrics(
            histogram: histogram,
            luminance: average,
            blackRatio: Float(blackPixels) / Float(size * size),
            brightRatio: Float(brightPixels) / Float(size * size),
            dominantToneRatio: histogram.max() ?? 1,
            sharpness: edgeEnergy / Float((size - 2) * (size - 2)),
            focusedEdgeRatio: edgeEnergy > 0 ? focusedEdgeEnergy / edgeEnergy : 0,
            contrast: sqrt(variance),
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
