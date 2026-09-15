import AppKit
import XCTest
@testable import ShotTesseraApp

final class FrameSelectionTests: XCTestCase {
    @MainActor
    func testBatchQueueAcceptsMultipleVideosAndRemovesDuplicates() {
        let model = StoryboardViewModel()
        let first = URL(fileURLWithPath: "/tmp/first.mp4")
        let second = URL(fileURLWithPath: "/tmp/second.mp4")
        model.addVideos([first, second, first])
        XCTAssertEqual(model.videoJobs.map(\.url), [first, second])
    }

    func testExportFilenameUsesShotSequence() {
        XCTAssertEqual(
            ExportDestination.filename(baseName: "concert", format: .png, sequence: 1),
            "concert-shot-001.png"
        )
        XCTAssertEqual(
            ExportDestination.filename(baseName: "concert", format: .jpeg, sequence: 42),
            "concert-shot-042.jpg"
        )
    }

    func testTimestampFormatting() {
        XCTAssertEqual(TimestampFormatter.string(for: 0), "00:00:00")
        XCTAssertEqual(TimestampFormatter.string(for: 83.9), "00:01:23")
        XCTAssertEqual(TimestampFormatter.string(for: 3_723), "01:02:03")
    }

    func testEmptyWatermarkTitleIsNotRenderedAndWhitespaceIsTrimmed() {
        var settings = ExportSettings()
        XCTAssertNil(settings.visibleTitleWatermark)

        settings.titleWatermark = "   \n "
        XCTAssertNil(settings.visibleTitleWatermark)

        settings.titleWatermark = "  夏日片段  "
        XCTAssertEqual(settings.visibleTitleWatermark, "夏日片段")
    }

    func testComposerRendersAVisibleTitleWatermark() throws {
        let sourceImage = NSImage(size: NSSize(width: 320, height: 180))
        sourceImage.lockFocus()
        NSColor(calibratedRed: 0.16, green: 0.34, blue: 0.58, alpha: 1).setFill()
        NSBezierPath(rect: NSRect(x: 0, y: 0, width: 320, height: 180)).fill()
        sourceImage.unlockFocus()
        let imageData = try XCTUnwrap(sourceImage.tiffRepresentation)
        let frames = (0..<9).map { index in
            CapturedFrame(id: index, time: Double(index), jpegData: imageData)
        }
        let result = StoryboardResult(frames: frames, sourceURL: URL(fileURLWithPath: "/tmp/sample.mp4"))
        let baseSettings = ExportSettings(gridSide: 3, format: .png, width: 1920)
        let plainData = try StoryboardComposer.render(result: result, settings: baseSettings)
        let titledData = try StoryboardComposer.render(
            result: result,
            settings: ExportSettings(gridSide: 3, format: .png, width: 1920, titleWatermark: "夏日片段")
        )
        XCTAssertNotEqual(plainData, titledData)
    }

    func testCommonVideoContainersAreAccepted() {
        for fileExtension in ["mp4", "mov", "mkv", "webm", "avi", "3gp", "mpeg", "ts"] {
            XCTAssertTrue(SupportedVideoInput.accepts(URL(fileURLWithPath: "/tmp/sample.\(fileExtension)")))
        }
        XCTAssertFalse(SupportedVideoInput.accepts(URL(fileURLWithPath: "/tmp/notes.txt")))
    }

    func testHistogramDistanceIsZeroForSameFrame() {
        XCTAssertEqual(FrameSelection.histogramDistance([0.5, 0.5], [0.5, 0.5]), 0, accuracy: 0.0001)
    }

    func testSceneDetectionSeparatesLargeHistogramChange() {
        let frames = [
            frame(id: 0, time: 0, histogram: [1, 0]),
            frame(id: 1, time: 1, histogram: [0.95, 0.05]),
            frame(id: 2, time: 2, histogram: [0.05, 0.95]),
            frame(id: 3, time: 3, histogram: [0, 1])
        ]
        XCTAssertEqual(FrameSelection.sceneRanges(in: frames).count, 2)
    }

    func testSelectionRejectsDarkAndNearDuplicateFrames() {
        let frames = [
            frame(id: 0, time: 0, histogram: [1, 0], blackRatio: 0.97, sharpness: 0.01, fingerprint: 0),
            frame(id: 1, time: 1, histogram: [0.8, 0.2], fingerprint: 1),
            frame(id: 2, time: 2, histogram: [0.8, 0.2], fingerprint: 3),
            frame(id: 3, time: 3, histogram: [0.1, 0.9], fingerprint: .max),
            frame(id: 4, time: 4, histogram: [0.4, 0.6], fingerprint: 0x0F0F_0F0F_0F0F_0F0F)
        ]
        let selected = FrameSelection.chooseFrames(from: frames, count: 3)
        XCTAssertFalse(selected.contains(where: { $0.id == 0 }))
        XCTAssertEqual(Set(selected.map(\.id)).count, selected.count)
    }

    func testSelectionFillsARequestedNineByNineGrid() {
        let frames = (0..<180).map { index in
            frame(
                id: index,
                time: Double(index) * 0.5,
                histogram: [0.45, 0.55],
                fingerprint: UInt64(index) << 16
            )
        }
        let selected = FrameSelection.chooseFrames(from: frames, count: 81)
        XCTAssertEqual(selected.count, 81)
        XCTAssertEqual(Set(selected.map(\.id)).count, 81)
    }

    func testAllBlackFramesProduceNoStoryboardCandidates() {
        let frames = (0..<12).map { index in
            frame(id: index, time: Double(index), histogram: [1, 0], blackRatio: 0.96, sharpness: 0.01, fingerprint: UInt64(index))
        }
        XCTAssertTrue(FrameSelection.chooseFrames(from: frames, count: 9).isEmpty)
    }

    func testDetectedPersonOutranksSimilarQualityLandscape() {
        let landscape = frame(id: 0, time: 0, histogram: [0.2, 0.8], sharpness: 0.22, fingerprint: 1)
        var portrait = frame(id: 1, time: 1, histogram: [0.8, 0.2], sharpness: 0.18, fingerprint: .max)
        portrait.peopleScore = 0.32
        XCTAssertEqual(FrameSelection.chooseFrames(from: [landscape, portrait], count: 1).first?.id, portrait.id)
    }

    private func frame(
        id: Int,
        time: Double,
        histogram: [Float],
        blackRatio: Float = 0.02,
        sharpness: Float = 0.22,
        fingerprint: UInt64 = UInt64.random(in: 10...100_000)
    ) -> FrameDescriptor {
        FrameDescriptor(
            id: id,
            time: time,
            histogram: histogram,
            luminance: 0.45,
            blackRatio: blackRatio,
            sharpness: sharpness,
            fingerprint: fingerprint,
            previewData: nil
        )
    }
}
