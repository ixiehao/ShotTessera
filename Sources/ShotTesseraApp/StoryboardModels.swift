import Foundation

enum ExportFormat: String, CaseIterable, Identifiable, Sendable {
    case png = "PNG"
    case jpeg = "JPG"

    var id: String { rawValue }
    var fileExtension: String { self == .png ? "png" : "jpg" }
}

enum StoryboardGrid {
    /// Six options keep the controls to two compact rows.
    static let availableSides = Array(3...8)
}

/// The card ratio also determines the exported contact-sheet direction because
/// every supported storyboard grid has the same number of rows and columns.
/// `source` is deliberately the default: it preserves a vertical, square, or
/// horizontal video's composition instead of forcing every frame into 16:9.
enum StoryboardAspect: CaseIterable, Identifiable, Sendable {
    case source
    case landscape
    case standard
    case square
    case vertical
    case portrait
    case ultraWide

    var id: Self { self }

    func label(in language: AppLanguage) -> String {
        language.text(localizationKey)
    }

    private var localizationKey: String {
        switch self {
        case .source: "aspect.source"
        case .landscape: "aspect.landscape"
        case .standard: "aspect.standard"
        case .square: "aspect.square"
        case .vertical: "aspect.vertical"
        case .portrait: "aspect.portrait"
        case .ultraWide: "aspect.ultraWide"
        }
    }

    private var fixedCardAspectRatio: Double? {
        switch self {
        case .source: nil
        case .landscape: 16.0 / 9.0
        case .standard: 4.0 / 3.0
        case .square: 1
        case .vertical: 3.0 / 4.0
        case .portrait: 9.0 / 16.0
        case .ultraWide: 21.0 / 9.0
        }
    }

    /// A guard rail for damaged metadata and unusually shaped image decodes.
    /// It still accommodates all common phone, square, film, and ultrawide ratios.
    func resolvedCardAspectRatio(sourceAspectRatio: Double?) -> Double {
        let candidate = fixedCardAspectRatio ?? sourceAspectRatio ?? (16.0 / 9.0)
        guard candidate.isFinite, candidate > 0 else { return 16.0 / 9.0 }
        return min(3, max(1.0 / 3.0, candidate))
    }
}

struct ExportSettings: Sendable {
    var gridSide: Int = 4
    var layoutAspect: StoryboardAspect = .source
    var language: AppLanguage = .chinese
    var format: ExportFormat = .png
    var width: Int = 2560
    var showTimestamps = false
    var showTitleWatermark = false

    var frameCount: Int { gridSide * gridSide }
    var safeWidth: Int { max(1920, min(width, 12_000)) }

    func resolvedCardAspectRatio(for frames: [CapturedFrame]) -> Double {
        layoutAspect.resolvedCardAspectRatio(sourceAspectRatio: frames.first?.aspectRatio)
    }

    func titleWatermark(for sourceURL: URL) -> String? {
        guard showTitleWatermark else { return nil }
        let title = sourceURL
            .deletingPathExtension()
            .lastPathComponent
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return nil }
        // File names can be unexpectedly long; preserve a useful title without
        // allowing it to obscure the entire storyboard.
        return String(title.prefix(72))
    }
}

enum TimestampFormatter {
    static func string(for seconds: Double) -> String {
        guard seconds.isFinite else { return "00:00:00" }
        let totalSeconds = max(0, Int(seconds.rounded(.down)))
        let hours = totalSeconds / 3_600
        let minutes = (totalSeconds % 3_600) / 60
        let remainder = totalSeconds % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, remainder)
    }
}

enum ExportDestination {
    static func filename(baseName: String, format: ExportFormat, sequence: Int) -> String {
        let suffix = String(format: "%03d", max(1, sequence))
        let ending = "-shot-\(suffix).\(format.fileExtension)"
        // macOS permits 255 UTF-8 bytes per filename, not 255 characters. Leave
        // space for the generated suffix without splitting a Unicode character.
        var safeBaseName = baseName.isEmpty ? "video" : baseName
        while safeBaseName.utf8.count + ending.utf8.count > 255 {
            safeBaseName.removeLast()
        }
        return "\(safeBaseName)\(ending)"
    }

    static func nextURL(for source: URL, format: ExportFormat, fileManager: FileManager = .default) -> URL {
        let folder = source.deletingLastPathComponent()
        let baseName = source.deletingPathExtension().lastPathComponent
        var sequence = 1
        while true {
            let candidate = folder.appendingPathComponent(filename(baseName: baseName, format: format, sequence: sequence))
            if !fileManager.fileExists(atPath: candidate.path) { return candidate }
            sequence += 1
        }
    }
}

/// A hint avoids rescanning all earlier outputs for every image in a batch.
/// The candidate is still checked on disk because another app may have created
/// it since the previous write. The writer actor owns and serializes this value.
struct ExportSequenceAllocator {
    private struct Key: Hashable {
        let folder: String
        let baseName: String
        let fileExtension: String
    }

    private var nextSequences: [Key: Int] = [:]

    mutating func nextURL(
        for source: URL,
        format: ExportFormat,
        fileExists: (String) -> Bool = { FileManager.default.fileExists(atPath: $0) }
    ) -> URL {
        let folder = source.deletingLastPathComponent().standardizedFileURL
        let baseName = source.deletingPathExtension().lastPathComponent
        let key = Key(folder: folder.path, baseName: baseName, fileExtension: format.fileExtension)
        var sequence = nextSequences[key] ?? 1
        while true {
            let candidate = folder.appendingPathComponent(
                ExportDestination.filename(baseName: baseName, format: format, sequence: sequence)
            )
            if !fileExists(candidate.path) {
                nextSequences[key] = sequence + 1
                return candidate
            }
            sequence += 1
        }
    }
}

enum VideoJobState: Equatable {
    case queued
    case processing
    case completed(String)
    case failed(VideoFailure)

    func label(in language: AppLanguage) -> String {
        switch self {
        case .queued: language.text("job.queued")
        case .processing: language.text("job.processing")
        case .completed: language.text("job.completed")
        case .failed: language.text("job.failed")
        }
    }

    var failureMessage: String? {
        guard case let .failed(failure) = self else { return nil }
        return failure.message
    }

    var canRetry: Bool {
        guard case let .failed(failure) = self else { return false }
        return failure.isRetryable
    }

    var needsTranscoding: Bool {
        guard case let .failed(failure) = self else { return false }
        return failure.needsTranscoding
    }
}

/// Only transient failures belong in the retry action. A decoder limitation is
/// deterministic, so sending it through the same batch again wastes time.
struct VideoFailure: Equatable {
    enum Kind: Equatable {
        case retryable, needsTranscoding, permanent
    }

    let message: String
    let kind: Kind

    var isRetryable: Bool { kind == .retryable }

    static func retryable(_ message: String) -> VideoFailure {
        VideoFailure(message: message, kind: .retryable)
    }

    static func needsTranscoding(_ message: String) -> VideoFailure {
        VideoFailure(message: message, kind: .needsTranscoding)
    }

    static func classify(_ error: Error, language: AppLanguage) -> VideoFailure {
        guard let error = error as? StoryboardError else { return .retryable(error.localizedDescription) }
        let message = error.message(in: language)
        switch error {
        case .unsupportedCodec: return .needsTranscoding(message)
        case .unreadableVideo, .noUsableFrames: return VideoFailure(message: message, kind: .permanent)
        case .noExportData: return .retryable(message)
        }
    }

    var needsTranscoding: Bool { kind == .needsTranscoding }
}

struct VideoJob: Identifiable, Equatable {
    let id: UUID
    let url: URL
    var state: VideoJobState

    init(url: URL, state: VideoJobState = .queued) {
        self.id = UUID()
        self.url = url
        self.state = state
    }
}

struct FrameDescriptor: Identifiable, Sendable {
    let id: Int
    let time: Double
    let histogram: [Float]
    let luminance: Float
    let blackRatio: Float
    let sharpness: Float
    let fingerprint: UInt64
    let previewData: Data?
    /// Set from the same AVFoundation image used for metrics, so choosing a
    /// source-matched layout never needs another image decode.
    var aspectRatio: Double = 16.0 / 9.0
    var peopleScore: Float = 0

    var isUsable: Bool {
        blackRatio < 0.82 && luminance > 0.045 && sharpness > 0.012
    }

    var qualityScore: Float {
        let exposure = min(1, max(0, (luminance - 0.08) / 0.40))
        let detail = min(1, sharpness / 0.18)
        let darknessPenalty = blackRatio * 1.4
        // A detected face or full body is a deliberate preference, not merely a
        // tie-breaker. Videos with no detected people still rank by visual quality.
        let personPreference: Float = peopleScore > 0.05 ? 0.45 + peopleScore * 0.60 : 0
        return max(0, exposure * 0.35 + detail * 0.55 + personPreference - darknessPenalty)
    }
}

struct CapturedFrame: Sendable, Identifiable {
    let id: Int
    let time: Double
    let jpegData: Data
    /// Captured after AVFoundation applies the video's preferred track transform,
    /// so a phone video is reported as vertical rather than its encoded rotation.
    let aspectRatio: Double

    init(id: Int, time: Double, jpegData: Data, aspectRatio: Double = 16.0 / 9.0) {
        self.id = id
        self.time = time
        self.jpegData = jpegData
        self.aspectRatio = aspectRatio
    }
}

struct StoryboardResult: Sendable {
    let frames: [CapturedFrame]
    let sourceURL: URL
    /// Kept with the selected frames so the lightweight manual adjuster can seek
    /// to a user-chosen moment without rescanning the whole movie.
    let duration: Double

    init(frames: [CapturedFrame], sourceURL: URL, duration: Double = 0) {
        self.frames = frames
        self.sourceURL = sourceURL
        self.duration = duration
    }
}

enum StoryboardError: LocalizedError {
    case unreadableVideo
    case unsupportedCodec
    case noUsableFrames
    case noExportData

    func message(in language: AppLanguage) -> String {
        switch self {
        case .unreadableVideo: language.text("error.unreadableVideo")
        case .unsupportedCodec: language.text("error.unsupportedCodec")
        case .noUsableFrames: language.text("error.noUsableFrames")
        case .noExportData: language.text("error.noExportData")
        }
    }

    var errorDescription: String? { message(in: .chinese) }
}
