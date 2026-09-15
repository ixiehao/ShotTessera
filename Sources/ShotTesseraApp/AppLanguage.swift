import Foundation

/// An in-app language choice. Keeping the selected language separate from the
/// macOS system language lets people use ShotTessera in their preferred language
/// without restarting the application.
enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    case chinese = "zh-Hans"
    case english = "en"
    case japanese = "ja"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .chinese: "中文"
        case .english: "English"
        case .japanese: "日本語"
        }
    }

    var locale: Locale { Locale(identifier: rawValue) }

    static let requiredLocalizationKeys = [
        "alert.generation.title", "button.ok", "app.tagline", "app.language", "app.icon.accessibility",
        "section.grid", "section.aspect", "aspect.source", "aspect.landscape", "aspect.standard",
        "aspect.square", "aspect.vertical", "aspect.portrait", "aspect.ultraWide", "aspect.help",
        "section.export", "export.autosave", "export.format", "export.width", "export.width.hint",
        "export.time", "export.title", "export.local.note", "export.title.note", "button.generate.single",
        "button.generate.batch", "button.cancel", "accessibility.generating", "accessibility.generate",
        "accessibility.analyzing", "preview.title", "button.saveas", "status.processing", "status.empty",
        "default.video", "processing.fast", "processing.people", "processing.assembling", "error.unsupportedInput",
        "status.cancelled", "status.nowProcessing", "status.saved", "status.generatedNotSaved", "status.failedContinue",
        "status.batchCompleted", "status.batchCompletedWithFailures", "job.queued", "job.processing", "job.completed",
        "job.failed", "queue.more", "queue.clear", "video.add", "video.added", "video.support",
        "video.queueHint", "preview.live", "preview.empty.title", "preview.empty.description", "error.unreadableVideo",
        "error.unsupportedCodec", "error.noUsableFrames", "error.noExportData"
    ]

    func text(_ key: String, _ arguments: CVarArg...) -> String {
        text(key, arguments: arguments)
    }

    func text(_ key: String, arguments: [CVarArg]) -> String {
        let format = localizationBundle.localizedString(forKey: key, value: key, table: nil)
        guard !arguments.isEmpty else { return format }
        return String(format: format, locale: locale, arguments: arguments)
    }

    private var localizationBundle: Bundle {
        guard let path = Bundle.module.path(forResource: rawValue, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return .module
        }
        return bundle
    }
}
