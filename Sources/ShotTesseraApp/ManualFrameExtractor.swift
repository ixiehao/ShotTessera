import AVFoundation
import CoreGraphics
import Foundation
import OSLog

/// A compact candidate sampler used only after a person opens the manual
/// adjuster. The normal storyboard path remains a single, fast analysis pass.
enum ManualFrameExtractor {
    private static let candidateBatchSignposter = OSSignposter(
        subsystem: Bundle.main.bundleIdentifier ?? "com.shottessera.app",
        category: "CandidateSampling"
    )
    private static let sharpnessBatchSignposter = OSSignposter(
        subsystem: Bundle.main.bundleIdentifier ?? "com.shottessera.app",
        category: "FrameRefinement"
    )

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

    /// Refines a selected manual set in two decoder batches: first score the
    /// same +/- 3-frame neighbourhood used by `captureSharpestFrame`, then
    /// decode only the winning moments at export size. Applying a 6 × 6 grid no
    /// longer starts 36 independent generators while preserving the exact
    /// sharpness formula and a per-frame fallback for damaged media.
    static func captureSharpestFrames(
        from asset: AVURLAsset,
        duration: Double,
        frames: [CapturedFrame],
        maximumEdge: CGFloat,
        compressionQuality: CGFloat
    ) async throws -> [CapturedFrame] {
        guard !frames.isEmpty else { return [] }
        let batchInterval = sharpnessBatchSignposter.beginInterval("selectedFrameRefinement")
        defer {
            sharpnessBatchSignposter.endInterval("selectedFrameRefinement", batchInterval)
        }

        let frameRate = await nominalFrameRate(for: asset)
        let plans = frames.enumerated().map { offset, frame in
            SharpnessPlan(
                index: offset,
                identifier: frame.id,
                centre: min(max(0, frame.time), max(0, duration - 0.001)),
                comparisonTimes: sharpnessComparisonTimes(
                    around: frame.time,
                    duration: duration,
                    frameRate: frameRate
                )
            )
        }

        let analysisGenerator = AVAssetImageGenerator(asset: asset)
        analysisGenerator.appliesPreferredTrackTransform = true
        let analysisEdge = sharpnessAnalysisMaximumEdge(for: maximumEdge)
        analysisGenerator.maximumSize = CGSize(width: analysisEdge, height: analysisEdge)
        analysisGenerator.requestedTimeToleranceBefore = .zero
        analysisGenerator.requestedTimeToleranceAfter = .zero
        defer { analysisGenerator.cancelAllCGImageGeneration() }

        let comparisonRequests = sharpnessRequestBatch(
            plans: plans,
            planIndices: Array(plans.indices),
            frameRate: frameRate
        ) { _, plan in plan.comparisonTimes }
        let scoringInterval = sharpnessBatchSignposter.beginInterval("selectedFrameScoringDecode")
        let bestByPlan: [SharpnessProbe?]
        do {
            defer {
                sharpnessBatchSignposter.endInterval("selectedFrameScoringDecode", scoringInterval)
            }
            bestByPlan = try await scoreSharpnessBatch(
                using: analysisGenerator,
                requestBatch: comparisonRequests,
                plans: plans,
                frameRate: frameRate
            )
        }

        let finalGenerator = AVAssetImageGenerator(asset: asset)
        finalGenerator.appliesPreferredTrackTransform = true
        finalGenerator.maximumSize = CGSize(width: maximumEdge, height: maximumEdge)
        finalGenerator.requestedTimeToleranceBefore = .zero
        finalGenerator.requestedTimeToleranceAfter = .zero
        defer { finalGenerator.cancelAllCGImageGeneration() }

        let finalRequests = sharpnessRequestBatch(
            plans: plans,
            planIndices: plans.indices.filter { bestByPlan[$0] != nil },
            frameRate: frameRate
        ) { index, _ in bestByPlan[index].map { [$0.time] } ?? [] }
        let finalInterval = sharpnessBatchSignposter.beginInterval("selectedFrameFinalDecode")
        let finalImages: [FinalSharpnessImage?]
        do {
            defer {
                sharpnessBatchSignposter.endInterval("selectedFrameFinalDecode", finalInterval)
            }
            finalImages = try await decodeFinalSharpnessBatch(
                using: finalGenerator,
                requestBatch: finalRequests,
                planCount: plans.count,
                frameRate: frameRate
            )
        }

        var output: [CapturedFrame] = []
        output.reserveCapacity(plans.count)
        for (index, plan) in plans.enumerated() {
            try Task.checkCancellation()
            guard let best = bestByPlan[index] else { continue }
            let final = finalImages[index]
            let image = final?.image ?? best.image
            guard let jpegData = ImageCodec.jpegData(from: image, compressionQuality: compressionQuality) else {
                continue
            }
            let capturedTime = final?.time ?? best.time
            let aspectRatio = image.height > 0
                ? Double(image.width) / Double(image.height)
                : 16.0 / 9.0
            output.append(CapturedFrame(
                id: plan.identifier,
                time: capturedTime,
                jpegData: jpegData,
                aspectRatio: aspectRatio
            ))
        }
        return output
    }

    private struct SharpnessPlan {
        let index: Int
        let identifier: Int
        let centre: Double
        let comparisonTimes: [Double]
    }

    private struct SharpnessProbe {
        let image: CGImage
        let time: Double
        let score: Float
    }

    private struct SharpnessRequestBatch {
        let requestedTimes: [CMTime]
        let planIndicesByRequestKey: [Int64: [Int]]
    }

    private struct FinalSharpnessImage {
        let image: CGImage
        let time: Double
    }

    private static func sharpnessRequestBatch(
        plans: [SharpnessPlan],
        planIndices: [Int],
        frameRate: Double,
        selecting times: (Int, SharpnessPlan) -> [Double]
    ) -> SharpnessRequestBatch {
        var requestedTimes: [CMTime] = []
        var planIndicesByRequestKey: [Int64: [Int]] = [:]
        var addedRequestKeys = Set<Int64>()

        for index in planIndices {
            var planRequestKeys = Set<Int64>()
            for seconds in times(index, plans[index]) {
                let key = candidateRequestKey(for: seconds, frameRate: frameRate)
                guard planRequestKeys.insert(key).inserted else { continue }
                planIndicesByRequestKey[key, default: []].append(index)
                if addedRequestKeys.insert(key).inserted {
                    requestedTimes.append(CMTime(seconds: seconds, preferredTimescale: 60_000))
                }
            }
        }
        return SharpnessRequestBatch(
            requestedTimes: requestedTimes.sorted { $0.seconds < $1.seconds },
            planIndicesByRequestKey: planIndicesByRequestKey
        )
    }

    private static func scoreSharpnessBatch(
        using generator: AVAssetImageGenerator,
        requestBatch: SharpnessRequestBatch,
        plans: [SharpnessPlan],
        frameRate: Double
    ) async throws -> [SharpnessProbe?] {
        var bestByPlan = Array<SharpnessProbe?>(repeating: nil, count: plans.count)
        guard !requestBatch.requestedTimes.isEmpty else { return bestByPlan }

        for await result in generator.images(for: requestBatch.requestedTimes) {
            try Task.checkCancellation()
            guard case let .success(requestedTime, image, actualTime) = result else { continue }
            let key = candidateRequestKey(for: requestedTime.seconds, frameRate: frameRate)
            guard let planIndices = requestBatch.planIndicesByRequestKey[key] else { continue }
            let resolvedTime = actualTime.isValid && actualTime.seconds.isFinite
                ? actualTime.seconds
                : requestedTime.seconds
            let score = autoreleasepool { () -> Float in
                let metrics = PixelMetrics.make(from: image)
                return visualClarityScore(metrics)
            }
            for index in planIndices {
                let distancePenalty = Float(abs(resolvedTime - plans[index].centre)) * 0.0001
                let probe = SharpnessProbe(image: image, time: resolvedTime, score: score - distancePenalty)
                if probe.score > (bestByPlan[index]?.score ?? -.greatestFiniteMagnitude) {
                    bestByPlan[index] = probe
                }
            }
        }
        return bestByPlan
    }

    private static func decodeFinalSharpnessBatch(
        using generator: AVAssetImageGenerator,
        requestBatch: SharpnessRequestBatch,
        planCount: Int,
        frameRate: Double
    ) async throws -> [FinalSharpnessImage?] {
        var results = Array<FinalSharpnessImage?>(repeating: nil, count: planCount)
        guard !requestBatch.requestedTimes.isEmpty else { return results }

        for await result in generator.images(for: requestBatch.requestedTimes) {
            try Task.checkCancellation()
            guard case let .success(requestedTime, image, actualTime) = result else { continue }
            let key = candidateRequestKey(for: requestedTime.seconds, frameRate: frameRate)
            guard let planIndices = requestBatch.planIndicesByRequestKey[key] else { continue }
            let resolvedTime = actualTime.isValid && actualTime.seconds.isFinite
                ? actualTime.seconds
                : requestedTime.seconds
            for index in planIndices {
                results[index] = FinalSharpnessImage(image: image, time: resolvedTime)
            }
        }
        return results
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

    /// Re-decodes only the final automatic tiles at presentation size after a
    /// lightweight broad scan. It uses the same tolerant seeking as the former
    /// broad pass, so this is a resolution upgrade rather than a new selection
    /// rule. Exact sharpness refinement, when needed, is applied separately.
    static func capturePresentationFrames(
        from asset: AVURLAsset,
        frames: [CapturedFrame],
        maximumEdge: CGFloat,
        compressionQuality: CGFloat
    ) async throws -> [CapturedFrame] {
        guard !frames.isEmpty else { return [] }
        let interval = sharpnessBatchSignposter.beginInterval("presentationFrameDecode")
        defer {
            sharpnessBatchSignposter.endInterval("presentationFrameDecode", interval)
        }

        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: maximumEdge, height: maximumEdge)
        let tolerance = CMTime(seconds: 0.75, preferredTimescale: 600)
        generator.requestedTimeToleranceBefore = tolerance
        generator.requestedTimeToleranceAfter = tolerance
        defer { generator.cancelAllCGImageGeneration() }

        var idsByRequestKey: [Int64: [Int]] = [:]
        var requestedTimes: [CMTime] = []
        var seenRequestKeys = Set<Int64>()
        for frame in frames {
            let key = presentationRequestKey(for: frame.time)
            idsByRequestKey[key, default: []].append(frame.id)
            if seenRequestKeys.insert(key).inserted {
                requestedTimes.append(CMTime(seconds: frame.time, preferredTimescale: 60_000))
            }
        }

        var capturedByID: [Int: CapturedFrame] = [:]
        for await result in generator.images(for: requestedTimes.sorted { $0.seconds < $1.seconds }) {
            try Task.checkCancellation()
            guard case let .success(requestedTime, image, actualTime) = result,
                  let identifiers = idsByRequestKey[presentationRequestKey(for: requestedTime.seconds)],
                  let jpegData = ImageCodec.jpegData(from: image, compressionQuality: compressionQuality) else {
                continue
            }
            let time = actualTime.isValid && actualTime.seconds.isFinite ? actualTime.seconds : requestedTime.seconds
            let aspectRatio = image.height > 0
                ? Double(image.width) / Double(image.height)
                : 16.0 / 9.0
            for identifier in identifiers {
                capturedByID[identifier] = CapturedFrame(
                    id: identifier,
                    time: time,
                    jpegData: jpegData,
                    aspectRatio: aspectRatio
                )
            }
        }
        return frames.compactMap { capturedByID[$0.id] }
    }

    static func captureCandidates(
        from videoURL: URL,
        gridSide: Int,
        outputWidth: Int,
        count: Int,
        batch: Int
    ) async throws -> [CapturedFrame] {
        let wholeBatch = candidateBatchSignposter.beginInterval("manualCandidateBatch")
        defer {
            candidateBatchSignposter.endInterval("manualCandidateBatch", wholeBatch)
        }

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
        defer { generator.cancelAllCGImageGeneration() }

        let sampleCount = max(1, count)
        // A deterministic phase shift makes “regenerate” produce a visibly
        // different yet evenly distributed set of moments without random jitter.
        let phase = Double((batch * 37) % 97) / 97.0
        let plans = (0..<sampleCount).map { index -> CandidatePlan in
            let shiftedProgress = (Double(index) + 0.5 + phase) / Double(sampleCount)
            let progress = shiftedProgress >= 1 ? shiftedProgress - 1 : shiftedProgress
            let requestedTime = min(max(0, duration * progress), max(0, duration - 0.01))
            return CandidatePlan(
                identifier: -((batch + 1) * 10_000 + index + 1),
                requestedTime: requestedTime,
                primaryTimes: candidateComparisonTimes(
                    around: requestedTime,
                    duration: duration,
                    frameRate: frameRate
                ),
                recoveryTimes: candidateRecoveryTimes(
                    around: requestedTime,
                    duration: duration,
                    frameRate: frameRate
                )
            )
        }

        // AVFoundation can decode a timeline of requested moments in one
        // stream. The former implementation created 3–5 independent exact
        // seeks per card; on a 72-card gallery that meant hundreds of serial
        // decoder restarts. Retain every sampling time and score unchanged,
        // while letting the framework batch their delivery.
        let allPlanIndices = Array(plans.indices)
        let primaryBatch = candidateRequestBatch(
            plans: plans,
            planIndices: allPlanIndices,
            selecting: \.primaryTimes,
            frameRate: frameRate
        )
        var bestByPlan = Array<CandidateProbe?>(repeating: nil, count: plans.count)
        do {
            let primaryInterval = candidateBatchSignposter.beginInterval("manualCandidatePrimaryDecode")
            defer {
                candidateBatchSignposter.endInterval("manualCandidatePrimaryDecode", primaryInterval)
            }
            bestByPlan = try await scoreCandidateBatch(
                using: generator,
                requestBatch: primaryBatch,
                plans: plans,
                existingBest: bestByPlan,
                frameRate: frameRate
            )
        }

        // Preserve the existing selective recovery behaviour. Only cards whose
        // strongest primary result still looks diffuse receive the two wider
        // probes, but those probes are also delivered as one decoder batch.
        let recoveryPlanIndices = plans.indices.filter {
            bestByPlan[$0].map { candidateNeedsRecovery($0.metrics) } == true
        }
        if !recoveryPlanIndices.isEmpty {
            let recoveryBatch = candidateRequestBatch(
                plans: plans,
                planIndices: recoveryPlanIndices,
                selecting: \.recoveryTimes,
                frameRate: frameRate
            )
            do {
                let recoveryInterval = candidateBatchSignposter.beginInterval("manualCandidateRecoveryDecode")
                defer {
                    candidateBatchSignposter.endInterval("manualCandidateRecoveryDecode", recoveryInterval)
                }
                bestByPlan = try await scoreCandidateBatch(
                    using: generator,
                    requestBatch: recoveryBatch,
                    plans: plans,
                    existingBest: bestByPlan,
                    frameRate: frameRate
                )
            }
        }

        var frames: [CapturedFrame] = []
        frames.reserveCapacity(sampleCount)
        for (index, plan) in plans.enumerated() {
            try Task.checkCancellation()
            guard let best = bestByPlan[index],
                  let jpegData = ImageCodec.jpegData(from: best.image, compressionQuality: 0.90) else {
                continue
            }
            let aspectRatio = best.image.height > 0
                ? Double(best.image.width) / Double(best.image.height)
                : 16.0 / 9.0
            frames.append(CapturedFrame(
                id: plan.identifier,
                time: best.time,
                jpegData: jpegData,
                aspectRatio: aspectRatio
            ))
        }

        guard !frames.isEmpty else { throw StoryboardError.noUsableFrames }
        return frames.sorted { $0.time < $1.time }
    }

    private struct CandidatePlan {
        let identifier: Int
        let requestedTime: Double
        let primaryTimes: [Double]
        let recoveryTimes: [Double]
    }

    private struct CandidateProbe {
        let image: CGImage
        let time: Double
        let metrics: PixelMetrics
        let score: Float
    }

    private struct CandidateRequestBatch {
        let requestedTimes: [CMTime]
        let planIndicesByRequestKey: [Int64: [Int]]
    }

    private static func candidateRequestBatch(
        plans: [CandidatePlan],
        planIndices: [Int],
        selecting times: KeyPath<CandidatePlan, [Double]>,
        frameRate: Double
    ) -> CandidateRequestBatch {
        var requestedTimes: [CMTime] = []
        var planIndicesByRequestKey: [Int64: [Int]] = [:]
        var addedRequestKeys = Set<Int64>()

        for index in planIndices {
            var planRequestKeys = Set<Int64>()
            for seconds in plans[index][keyPath: times] {
                let key = candidateRequestKey(for: seconds, frameRate: frameRate)
                // A request can collapse to the same source frame near a clip
                // boundary. Like the previous per-card probe, score it once.
                guard planRequestKeys.insert(key).inserted else { continue }
                planIndicesByRequestKey[key, default: []].append(index)
                if addedRequestKeys.insert(key).inserted {
                    requestedTimes.append(CMTime(seconds: seconds, preferredTimescale: 60_000))
                }
            }
        }
        return CandidateRequestBatch(
            requestedTimes: requestedTimes.sorted { $0.seconds < $1.seconds },
            planIndicesByRequestKey: planIndicesByRequestKey
        )
    }

    private static func scoreCandidateBatch(
        using generator: AVAssetImageGenerator,
        requestBatch: CandidateRequestBatch,
        plans: [CandidatePlan],
        existingBest: [CandidateProbe?],
        frameRate: Double
    ) async throws -> [CandidateProbe?] {
        guard !requestBatch.requestedTimes.isEmpty else { return existingBest }
        var bestByPlan = existingBest

        for await result in generator.images(for: requestBatch.requestedTimes) {
            try Task.checkCancellation()
            guard case let .success(requestedTime, image, actualTime) = result else { continue }
            let requestKey = candidateRequestKey(for: requestedTime.seconds, frameRate: frameRate)
            guard let planIndices = requestBatch.planIndicesByRequestKey[requestKey] else { continue }

            let resolvedTime = actualTime.isValid && actualTime.seconds.isFinite
                ? actualTime.seconds
                : requestedTime.seconds
            let metrics = autoreleasepool { PixelMetrics.make(from: image) }
            for index in planIndices {
                // Keep candidates close to their intended time, while allowing a
                // nearby clear frame to win over an obvious ghost frame.
                let distancePenalty = Float(abs(resolvedTime - plans[index].requestedTime)) * 0.025
                let probe = CandidateProbe(
                    image: image,
                    time: resolvedTime,
                    metrics: metrics,
                    score: visualClarityScore(metrics) - distancePenalty
                )
                if probe.score > (bestByPlan[index]?.score ?? -.greatestFiniteMagnitude) {
                    bestByPlan[index] = probe
                }
            }
        }
        return bestByPlan
    }

    private static func candidateRequestKey(for seconds: Double, frameRate: Double) -> Int64 {
        Int64((seconds * max(1, frameRate)).rounded())
    }

    private static func presentationRequestKey(for seconds: Double) -> Int64 {
        Int64((seconds * 60_000).rounded())
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
