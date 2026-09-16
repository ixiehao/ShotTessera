import AVFoundation
import CoreGraphics
import Foundation

/// A compact candidate sampler used only after a person opens the manual
/// adjuster. The normal storyboard path remains a single, fast analysis pass.
enum ManualFrameExtractor {
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

        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        let estimatedCellWidth = Double(max(1_920, outputWidth)) / Double(max(1, gridSide))
        let maximumEdge = min(1_280, max(480, estimatedCellWidth * 1.15))
        generator.maximumSize = CGSize(width: CGFloat(maximumEdge), height: CGFloat(maximumEdge))
        // Candidate browsing is manual and should still feel immediate. A keyframe
        // tolerance makes this far cheaper than a frame-accurate editing timeline.
        let tolerance = CMTime(seconds: 0.45, preferredTimescale: 600)
        generator.requestedTimeToleranceBefore = tolerance
        generator.requestedTimeToleranceAfter = tolerance

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
            let frame: CapturedFrame? = autoreleasepool {
                var actualTime = CMTime.zero
                guard let image = try? generator.copyCGImage(
                    at: CMTime(seconds: requestedTime, preferredTimescale: 600),
                    actualTime: &actualTime
                ), let jpegData = ImageCodec.jpegData(from: image, compressionQuality: 0.90) else {
                    return nil
                }

                let actualSeconds = actualTime.seconds
                let capturedTime = actualTime.isValid && actualSeconds.isFinite ? actualSeconds : requestedTime
                let aspectRatio = image.height > 0 ? Double(image.width) / Double(image.height) : 16.0 / 9.0
                return CapturedFrame(
                    id: -((batch + 1) * 10_000 + index + 1),
                    time: capturedTime,
                    jpegData: jpegData,
                    aspectRatio: aspectRatio
                )
            }
            if let frame {
                frames.append(frame)
            }
        }

        guard !frames.isEmpty else { throw StoryboardError.noUsableFrames }
        return frames.sorted { $0.time < $1.time }
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
