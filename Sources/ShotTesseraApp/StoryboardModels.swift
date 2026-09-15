import Foundation

enum ExportFormat: String, CaseIterable, Identifiable, Sendable {
    case png = "PNG"
    case jpeg = "JPG"

    var id: String { rawValue }
    var fileExtension: String { self == .png ? "png" : "jpg" }
}

struct ExportSettings: Sendable {
    var gridSide: Int = 4
    var format: ExportFormat = .png
    var width: Int = 2560

    var frameCount: Int { gridSide * gridSide }
    var safeWidth: Int { max(1920, min(width, 12_000)) }
}

enum ExportDestination {
    static func filename(baseName: String, format: ExportFormat, sequence: Int) -> String {
        let safeBaseName = baseName.isEmpty ? "video" : baseName
        let suffix = String(format: "%03d", max(1, sequence))
        return "\(safeBaseName)-shot-\(suffix).\(format.fileExtension)"
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

enum VideoJobState: Equatable {
    case queued
    case processing
    case completed(String)
    case failed(String)

    var label: String {
        switch self {
        case .queued: "等待处理"
        case .processing: "处理中"
        case .completed: "已保存"
        case .failed: "失败"
        }
    }
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
}

struct StoryboardResult: Sendable {
    let frames: [CapturedFrame]
    let sourceURL: URL
}

enum StoryboardError: LocalizedError {
    case unreadableVideo
    case noUsableFrames
    case noExportData

    var errorDescription: String? {
        switch self {
        case .unreadableVideo: "无法读取此视频。请尝试 MP4 或 MOV 文件。"
        case .noUsableFrames: "没有找到足够清晰、明亮的画面。"
        case .noExportData: "无法生成导出图片。"
        }
    }
}
