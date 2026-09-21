import AVFoundation
import CoreGraphics
import Foundation

/// A compact candidate sampler used only after a person opens the manual
/// adjuster. The normal storyboard path remains a single, fast analysis pass.
enum ManualFrameExtractor {
    /// Around a proposed moment, compare the surrounding decoded frames and
    /// retain the one with the strongest fine detail. Three frames on each side
    /// is short enough to preserve the intended moment, while being wide enough
    /// to escape motion blur from a pan, a step, or a fast subject.
    static func captureSharpestFrame(
        from asset: AVURLAsset,
        duration: Double,
        at requestedTime: Double,
        identifier: Int,
        maximumEdge: CGFloat,
        compressionQuality: CGFloat
    ) async throws -> CapturedFrame {
        let boundedDuration = max(0, duration - 0.001)
        let centre = min(max(0, requestedTime), boundedDuration)
        let frameRate = await nominalFrameRate(for: asset)
        // Decoding every comparison image at export resolution made a seven-frame
        // check substantially more expensive than the actual final decode. Fine
        // detail scoring operates on a compact luminance grid, so cap this first
        // pass and decode only the winning timestamp at the requested resolution.
        let analysisGenerator = AVAssetImageGenerator(asset: asset)
        analysisGenerator.appliesPreferredTrackTransform = true
        analysisGenerator.maximumSize = CGSize(
            width: sharpnessAnalysisMaximumEdge(for: maximumEdge),
            height: sharpnessAnalysisMaximumEdge(for: maximumEdge)
        )
        // This pass intentionally uses exact seeking. The earlier, tolerant
        // sampling pass stays fast; only the small +/- 3-frame neighbourhood
        // needs frame-level precision.
        analysisGenerator.requestedTimeToleranceBefore = .zero
        analysisGenerator.requestedTimeToleranceAfter = .zero

        var best: (fallbackImage: CGImage, time: Double, score: Float)?
        for sampleTime in sharpnessComparisonTimes(
            around: centre,
            duration: duration,
            frameRate: frameRate
        ) {
            try Task.checkCancellation()
            let candidate: (image: CGImage, time: Double, score: Float)? = autoreleasepool {
                var actualTime = CMTime.zero
                guard let image = try? analysisGenerator.copyCGImage(
                    at: CMTime(seconds: sampleTime, preferredTimescale: 60_000),
                    actualTime: &actualTime
                ) else { return nil }

                let resolvedTime = actualTime.isValid && actualTime.seconds.isFinite
                    ? actualTime.seconds
                    : sampleTime
                let metrics = PixelMetrics.make(from: image)
                // Raw edge energy alone wrongly rewards cross-dissolves and
                // double-image trails. Prefer concentrated edges and balanced
                // exposure, which keeps the final export aligned with the
                // cleaner cards shown in the manual candidate gallery.
                let visibleDetail = visualClarityScore(metrics)
                let distancePenalty = Float(abs(resolvedTime - centre)) * 0.0001
                return (image, resolvedTime, visibleDetail - distancePenalty)
            }
            try Task.checkCancellation()
            guard let candidate else { continue }
            let score = candidate.score
            if best == nil || score > best!.score {
                best = (candidate.image, candidate.time, score)
            }
        }

        guard let best else {
            throw StoryboardError.noUsableFrames
        }
        try Task.checkCancellation()

        // One full-resolution, exact decode preserves final export quality while
        // keeping the seven-frame comparison cheap. Retain the scored thumbnail
        // as a graceful fallback for damaged/VFR media whose second seek fails.
        let finalGenerator = AVAssetImageGenerator(asset: asset)
        finalGenerator.appliesPreferredTrackTransform = true
        finalGenerator.maximumSize = CGSize(width: maximumEdge, height: maximumEdge)
        finalGenerator.requestedTimeToleranceBefore = .zero
        finalGenerator.requestedTimeToleranceAfter = .zero
        var finalActualTime = CMTime.zero
        let finalImage = try? finalGenerator.copyCGImage(
            at: CMTime(seconds: best.time, preferredTimescale: 60_000),
            actualTime: &finalActualTime
        )
        try Task.checkCancellation()
        let image = finalImage ?? best.fallbackImage
        guard let jpegData = ImageCodec.jpegData(from: image, compressionQuality: compressionQuality) else {
            throw StoryboardError.noUsableFrames
        }
        let resolvedTime = finalImage != nil && finalActualTime.isValid && finalActualTime.seconds.isFinite
            ? finalActualTime.seconds
            : best.time
        let aspectRatio = image.height > 0
            ? Double(image.width) / Double(image.height)
            : 16.0 / 9.0
        return CapturedFrame(id: identifier, time: resolvedTime, jpegData: jpegData, aspectRatio: aspectRatio)
    }

    /// PixelMetrics reduces every image to 48 × 48 before scoring. Limiting the
    /// comparison decode to 480 px is therefore visually equivalent for this
    /// decision while sharply reducing decode, memory, and JPEG-buffer pressure.
    static func sharpnessAnalysisMaximumEdge(for requestedMaximumEdge: CGFloat) -> CGFloat {
        min(480, max(1, requestedMaximumEdge))
    }

    /// Kept deterministic and separately testable: a normal 30 fps moment has
    /// exactly 7 comparison points (the target plus three frames on either side).
    static func sharpnessComparisonTimes(
        around time: Double,
        duration: Double,
        frameRate: Double,
        neighbourhoodFrames: Int = 3
    ) -> [Double] {
        guard duration.isFinite, duration > 0 else { return [] }
        let safeRate = frameRate.isFinite && frameRate > 1 ? frameRate : 30
        let centre = min(max(0, time), max(0, duration - 0.001))
        let step = 1.0 / safeRate
        var times: [Double] = []
        var seen = Set<Int64>()
        for offset in -max(0, neighbourhoodFrames)...max(0, neighbourhoodFrames) {
            let candidate = min(max(0, centre + Double(offset) * step), max(0, duration - 0.001))
            // At either end several offsets collapse to the same frame.
            let key = Int64((candidate * safeRate).rounded())
            if seen.insert(key).inserted {
                times.append(candidate)
            }
        }
        return times
    }

    /// Decodes one user-positioned frame for the manual editor's preview
    /// timeline. This is deliberately separate from candidate sampling: moving
    /// the scrubber must never replace, reorder, or otherwise disturb the
    /// existing automatic candidates.
    static func captureFrame(
        from videoURL: URL,
        at requestedTime: Double,
        identifier: Int,
        maximumEdge: CGFloat = 1_600
    ) async throws -> CapturedFrame {
        let asset = AVURLAsset(url: videoURL)
        guard try await asset.load(.isPlayable) else { throw StoryboardError.unsupportedCodec }
        let duration = try await asset.load(.duration).seconds
        guard duration.isFinite, duration > 0 else { throw StoryboardError.unreadableVideo }

        let time = min(max(0, requestedTime), max(0, duration - 0.01))
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: maximumEdge, height: maximumEdge)
        // A manual addition should represent the time the person chose, rather
        // than a nearby key frame as used by the fast gallery sampler.
        let tolerance = CMTime(seconds: 0.04, preferredTimescale: 600)
        generator.requestedTimeToleranceBefore = tolerance
        generator.requestedTimeToleranceAfter = tolerance

        var actualTime = CMTime.zero
        guard let image = try? generator.copyCGImage(
            at: CMTime(seconds: time, preferredTimescale: 600),
            actualTime: &actualTime
        ), let jpegData = ImageCodec.jpegData(from: image, compressionQuality: 0.92) else {
            throw StoryboardError.noUsableFrames
        }

        let actualSeconds = actualTime.seconds
        let capturedTime = actualTime.isValid && actualSeconds.isFinite ? actualSeconds : time
        let aspectRatio = image.height > 0 ? Double(image.width) / Double(image.height) : 16.0 / 9.0
        return CapturedFrame(
            id: identifier,
            time: capturedTime,
            jpegData: jpegData,
            aspectRatio: aspectRatio
        )
    }

    static func captureCandidates(
        from videoURL: URL,
        gridSide: Int,
        outputWidth: Int,
        count: Int,
        batch: Int
    ) async throws -> [CapturedFrame] {
        let asset = AVURLAsset(url: videoURL)
        guard try await asset.load(.isPlayable) else { throw StoryboardError.unsupportedCodec }
        let duration = try await asset.load(.duration).seconds
        guard duration.isFinite, duration > 0 else { throw StoryboardError.unreadableVideo }

        let frameRate = await nominalFrameRate(for: asset)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        let estimatedCellWidth = Double(max(1_920, outputWidth)) / Double(max(1, gridSide))
        let maximumEdge = min(1_280, max(480, estimatedCellWidth * 1.15))
        // Gallery cards only need enough pixels for clear review. Limiting these
        // probes to 640px gives us room to inspect a tiny neighbourhood without
        // regressing the editor's perceived load time.
        let analysisEdge = min(640, maximumEdge)
        generator.maximumSize = CGSize(width: CGFloat(analysisEdge), height: CGFloat(analysisEdge))
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero

        let sampleCount = max(1, count)
        // A deterministic phase shift makes “regenerate” produce a visibly
        // different yet evenly distributed set of moments without random jitter.
        let phase = Double((batch * 37) % 97) / 97.0
        var frames: [CapturedFrame] = []
        frames.reserveCapacity(sampleCount)

        for index in 0..<sampleCount {
            try Task.checkCancellation()
            let shiftedProgress = (Double(index) + 0.5 + phase) / Double(sampleCount)
            let progress = shiftedProgress >= 1 ? shiftedProgress - 1 : shiftedProgress
            let requestedTime = min(max(0, duration * progress), max(0, duration - 0.01))
            let frame = clearestCandidateFrame(
                using: generator,
                around: requestedTime,
                duration: duration,
                frameRate: frameRate,
                identifier: -((batch + 1) * 10_000 + index + 1)
            )
            if let frame { frames.append(frame) }
        }

        guard !frames.isEmpty else { throw StoryboardError.noUsableFrames }
        return frames.sorted { $0.time < $1.time }
    }

    /// Gallery sampling must not present a dissolve, flash, or motion trail as a
    /// plausible selectable still. Probe just three nearby exact frames (rather
    /// than the seven-frame, full-resolution export refinement), then prefer the
    /// one with concentrated edges and balanced exposure. This is deliberately
    /// bounded: candidate loading remains interactive even for a 64-cell grid.
    private static func clearestCandidateFrame(
        using generator: AVAssetImageGenerator,
        around requestedTime: Double,
        duration: Double,
        frameRate: Double,
        identifier: Int
    ) -> CapturedFrame? {
        typealias Probe = (image: CGImage, time: Double, metrics: PixelMetrics, score: Float)
        var best: Probe?
        var probedTimes = Set<Int64>()

        func probe(_ sampleTime: Double) -> Probe? {
            // Generators occasionally resolve adjacent requested moments to the
            // same decoded frame. Avoid measuring that frame twice when a
            // recovery probe is needed.
            let requestKey = Int64((sampleTime * max(1, frameRate)).rounded())
            guard probedTimes.insert(requestKey).inserted else { return nil }
            let candidate: Probe? = autoreleasepool {
                var actualTime = CMTime.zero
                guard let image = try? generator.copyCGImage(
                    at: CMTime(seconds: sampleTime, preferredTimescale: 60_000),
                    actualTime: &actualTime
                ) else { return nil }

                let resolvedTime = actualTime.isValid && actualTime.seconds.isFinite
                    ? actualTime.seconds
                    : sampleTime
                let metrics = PixelMetrics.make(from: image)
                // Keep candidates close to their intended time, while allowing a
                // nearby clear frame to win over an obvious ghost frame.
                let distancePenalty = Float(abs(resolvedTime - requestedTime)) * 0.025
                return (image, resolvedTime, metrics, visualClarityScore(metrics) - distancePenalty)
            }
            return candidate
        }

        for sampleTime in candidateComparisonTimes(
            around: requestedTime,
            duration: duration,
            frameRate: frameRate
        ) {
            guard let candidate = probe(sampleTime) else { continue }
            if best == nil || candidate.score > best!.score { best = candidate }
        }

        // Do not make every card decode a wider neighbourhood. Only a weak,
        // diffuse result—typical of a dissolve, double exposure, or motion
        // trail—gets two extra probes roughly a third of a second away. This
        // escapes transitions without regressing candidate-grid load time.
        if best.map({ candidateNeedsRecovery($0.metrics) }) == true {
            for sampleTime in candidateRecoveryTimes(
                around: requestedTime,
                duration: duration,
                frameRate: frameRate
            ) {
                guard let candidate = probe(sampleTime) else { continue }
                if candidate.score > (best?.score ?? -.greatestFiniteMagnitude) {
                    best = candidate
                }
            }
        }

        guard let best,
              let jpegData = ImageCodec.jpegData(from: best.image, compressionQuality: 0.90) else {
            return nil
        }
        let aspectRatio = best.image.height > 0
            ? Double(best.image.width) / Double(best.image.height)
            : 16.0 / 9.0
        return CapturedFrame(id: identifier, time: best.time, jpegData: jpegData, aspectRatio: aspectRatio)
    }

    /// A compact three-point probe is intentionally wider than the final
    /// export's +/- 3-frame refinement. A dissolve commonly lasts half a
    /// second or more; a 3-frame probe would keep all three samples inside the
    /// same ghost image. We still decode only three 640px images per gallery
    /// card, but place the outer probes on either side of a normal transition.
    static func candidateComparisonTimes(
        around time: Double,
        duration: Double,
        frameRate: Double
    ) -> [Double] {
        guard duration.isFinite, duration > 0 else { return [] }
        let safeRate = frameRate.isFinite && frameRate > 1 ? frameRate : 30
        let centre = min(max(0, time), max(0, duration - 0.001))
        let step = min(0.45, max(0.30, 15.0 / safeRate))
        var times: [Double] = []
        var seen = Set<Int64>()
        for offset in [-1.0, 0, 1.0] {
            let candidate = min(max(0, centre + offset * step), max(0, duration - 0.001))
            let key = Int64((candidate * safeRate).rounded())
            if seen.insert(key).inserted { times.append(candidate) }
        }
        return times
    }

    /// Recovery probes are deliberately separate from the normal three-frame
    /// pass: they are evaluated only for a likely ghost frame. Keeping the
    /// offset at ten frames preserves the represented scene while reaching the
    /// stable side of a short cross-dissolve or a fast action blur.
    static func candidateRecoveryTimes(
        around time: Double,
        duration: Double,
        frameRate: Double
    ) -> [Double] {
        guard duration.isFinite, duration > 0 else { return [] }
        let safeRate = frameRate.isFinite && frameRate > 1 ? frameRate : 30
        let centre = min(max(0, time), max(0, duration - 0.001))
        let step = 10.0 / safeRate
        var times: [Double] = []
        var seen = Set<Int64>()
        for offset in [-1.0, 1.0] {
            let candidate = min(max(0, centre + offset * step), max(0, duration - 0.001))
            let key = Int64((candidate * safeRate).rounded())
            if seen.insert(key).inserted { times.append(candidate) }
        }
        return times
    }

    /// A ghost image can carry plenty of weak edges, so it needs a stricter
    /// gate than simple sharpness. This only controls whether the two bounded
    /// recovery probes run; the highest visual-quality frame still wins.
    static func candidateNeedsRecovery(_ metrics: PixelMetrics) -> Bool {
        visualClarityScore(metrics) < 0.48
            || metrics.focusedEdgeRatio < 0.38
            || (metrics.sharpness < 0.095 && metrics.contrast < 0.14)
    }

    private static func visualClarityScore(_ metrics: PixelMetrics) -> Float {
        let detail = min(1, metrics.sharpness / 0.18)
        let focusedEdges = min(1, metrics.focusedEdgeRatio / 0.62)
        let contrast = min(1, metrics.contrast / 0.24)
        let exposure = min(1, max(0, (metrics.luminance - 0.06) / 0.32))
        let clippingPenalty = max(0, metrics.brightRatio - 0.40) * 0.28
            + max(0, metrics.blackRatio - 0.68) * 0.10
        let diffuseEdgePenalty = max(0, 0.45 - metrics.focusedEdgeRatio) * 0.30
        let lowContrastPenalty = max(0, 0.10 - metrics.contrast) * 0.20
        return detail * 0.43 + focusedEdges * 0.39 + contrast * 0.14 + exposure * 0.04
            - clippingPenalty - diffuseEdgePenalty - lowContrastPenalty
    }

    private static func nominalFrameRate(for asset: AVURLAsset) async -> Double {
        guard let track = try? await asset.loadTracks(withMediaType: .video).first,
              let rate = try? await track.load(.nominalFrameRate),
              rate.isFinite, rate > 1 else { return 30 }
        return Double(rate)
    }
}

/// Reuses the automatic path's visual quality and de-duplication rules for the
/// already-decoded candidate gallery. It intentionally skips a second Vision
/// pass, making the one-click suggestion nearly immediate.
enum ManualFrameSelector {
    static func selectIDs(from candidates: [CapturedFrame], count: Int) -> [Int] {
        let targetCount = min(max(0, count), candidates.count)
        guard targetCount > 0 else { return [] }

        let descriptors = candidates.compactMap { candidate -> FrameDescriptor? in
            guard let image = ImageCodec.cgImage(from: candidate.jpegData) else {
                return nil
            }
            let metrics = PixelMetrics.make(from: image)
            var descriptor = FrameDescriptor(
                id: candidate.id,
                time: candidate.time,
                histogram: metrics.histogram,
                luminance: metrics.luminance,
                blackRatio: metrics.blackRatio,
                sharpness: metrics.sharpness,
                fingerprint: metrics.fingerprint,
                previewData: candidate.jpegData
            )
            descriptor.aspectRatio = candidate.aspectRatio
            return descriptor
        }

        var selectedIDs = Set(FrameSelection.chooseFrames(from: descriptors, count: targetCount).map(\.id))
        if selectedIDs.count < targetCount {
            let remaining = candidates
                .filter { !selectedIDs.contains($0.id) }
                .sorted { $0.time < $1.time }
            selectedIDs.formUnion(evenlySpacedIDs(from: remaining, count: targetCount - selectedIDs.count))
        }

        // A damaged thumbnail should not make the manual editor impossible to
        // complete. Use any remaining candidate only after the visual rules and
        // distributed fallback have been exhausted.
        if selectedIDs.count < targetCount {
            for candidate in candidates where selectedIDs.count < targetCount {
                selectedIDs.insert(candidate.id)
            }
        }
        return candidates
            .filter { selectedIDs.contains($0.id) }
            .sorted { $0.time < $1.time }
            .prefix(targetCount)
            .map(\.id)
    }

    private static func evenlySpacedIDs(from candidates: [CapturedFrame], count: Int) -> [Int] {
        guard count > 0, !candidates.isEmpty else { return [] }
        guard candidates.count > count else { return candidates.map(\.id) }
        if count == 1 { return [candidates[candidates.count / 2].id] }
        return (0..<count).map { slot in
            let position = Double(slot) * Double(candidates.count - 1) / Double(count - 1)
            return candidates[Int(position.rounded())].id
        }
    }
}
