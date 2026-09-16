import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var model = StoryboardViewModel()
    @AppStorage("appLanguage") private var languageCode = AppLanguage.chinese.rawValue
    @State private var isLanguagePickerPresented = false
    @State private var isAspectPickerPresented = false
    @State private var isWidthPickerPresented = false

    private var language: AppLanguage {
        AppLanguage(rawValue: languageCode) ?? .chinese
    }

    private func t(_ key: String, _ arguments: CVarArg...) -> String {
        language.text(key, arguments: arguments)
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            LinearGradient(
                colors: [Color(red: 0.05, green: 0.06, blue: 0.10), Color(red: 0.10, green: 0.075, blue: 0.16)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            HStack(spacing: 28) {
                controlPanel
                    .frame(width: 332)
                previewPanel
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding(30)

            languageMenu
                .padding(.top, 18)
                .padding(.trailing, 22)
        }
        .environment(\.locale, language.locale)
        .onAppear { model.language = language }
        .onChange(of: languageCode) { newValue in
            model.language = AppLanguage(rawValue: newValue) ?? .chinese
        }
        .onDrop(of: [.fileURL], isTargeted: $model.isDropTargeted, perform: model.acceptDrop)
        .alert(t("alert.generation.title"), isPresented: $model.showError) {
            Button(t("button.ok"), role: .cancel) { }
        } message: {
            Text(model.errorMessage)
        }
    }

    private var languageMenu: some View {
        Button {
            isLanguagePickerPresented.toggle()
        } label: {
            HStack(spacing: 7) {
                Image(systemName: "globe")
                    .foregroundStyle(Color(red: 0.48, green: 0.88, blue: 0.93))
                Text(language.displayName)
                    .foregroundStyle(PreviewText.primary)
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(PreviewText.secondary)
            }
            .font(.system(size: 12, weight: .semibold))
            .frame(width: 118, height: 34)
            .contentShape(Capsule())
            .background(Color(red: 0.12, green: 0.17, blue: 0.28).opacity(0.96), in: Capsule())
            .overlay {
                Capsule().strokeBorder(Color(red: 0.43, green: 0.80, blue: 0.90).opacity(0.62))
            }
            .shadow(color: .black.opacity(0.25), radius: 8, y: 3)
        }
        .buttonStyle(.plain)
        .frame(width: 118, height: 34)
        .accessibilityLabel(t("app.language"))
        .popover(isPresented: $isLanguagePickerPresented, arrowEdge: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(t("app.language"))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.bottom, 2)

                ForEach(AppLanguage.allCases) { choice in
                    Button {
                        languageCode = choice.rawValue
                        isLanguagePickerPresented = false
                    } label: {
                        HStack {
                            Text(choice.displayName)
                            Spacer()
                            if choice == language {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 7)
                        .background(choice == language ? Color.accentColor.opacity(0.12) : .clear, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity, minHeight: 34)
                    .contentShape(Rectangle())
                }
            }
            .padding(8)
            .frame(width: 156)
        }
    }

    private var aspectSelector: some View {
        Button {
            isAspectPickerPresented.toggle()
        } label: {
            HStack(spacing: 4) {
                Text(t("section.aspect"))
                    .font(.system(size: 11, weight: .medium))
                Spacer(minLength: 0)
                Text(model.layoutAspect.label(in: language))
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.secondary)
            }
            .foregroundStyle(.primary)
            .compactOptionSurface()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .accessibilityLabel(t("section.aspect"))
        .disabled(model.isProcessing)
        .popover(isPresented: $isAspectPickerPresented, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 4) {
                Text(t("section.aspect"))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.bottom, 2)

                ForEach(StoryboardAspect.allCases) { aspect in
                    Button {
                        model.layoutAspect = aspect
                        isAspectPickerPresented = false
                    } label: {
                        HStack {
                            Text(aspect.label(in: language))
                            Spacer()
                            if aspect == model.layoutAspect {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 7)
                        .background(aspect == model.layoutAspect ? Color.accentColor.opacity(0.12) : .clear, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity, minHeight: 34)
                    .contentShape(Rectangle())
                }
            }
            .padding(8)
            .frame(width: 178)
        }
    }

    private var widthSelector: some View {
        Button {
            isWidthPickerPresented.toggle()
        } label: {
            HStack(spacing: 4) {
                Text(t("export.width"))
                    .font(.system(size: 11, weight: .medium))
                Spacer(minLength: 0)
                Text(t("export.width.value", model.width))
                    .font(.system(size: 11, weight: .medium))
                    .monospacedDigit()
                    .lineLimit(1)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.secondary)
            }
            .foregroundStyle(.primary)
            .compactOptionSurface()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .accessibilityLabel(t("export.width"))
        .disabled(model.isProcessing)
        .popover(isPresented: $isWidthPickerPresented, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 4) {
                Text(t("export.width"))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.bottom, 2)

                ForEach(outputWidthChoices, id: \.self) { width in
                    Button {
                        model.width = width
                        isWidthPickerPresented = false
                    } label: {
                        HStack {
                            Text(t("export.width.value", width))
                                .monospacedDigit()
                            Spacer()
                            if width == model.width {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 7)
                        .background(width == model.width ? Color.accentColor.opacity(0.12) : .clear, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity, minHeight: 34)
                    .contentShape(Rectangle())
                }
            }
            .padding(8)
            .frame(width: 148)
        }
    }

    private var outputWidthChoices: [Int] { [1920, 2560, 3840, 5120, 7680, 12_000] }

    private var controlPanel: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 12) {
                ShotTesseraMark(language: language)
                VStack(alignment: .leading, spacing: 2) {
                    Text("ShotTessera")
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                    Text(t("app.tagline"))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }

            VideoBatchCard(jobs: model.videoJobs, language: language, isTargeted: model.isDropTargeted, isProcessing: model.isProcessing) {
                model.chooseVideo()
            } clear: {
                model.clearVideos()
            }

            VStack(alignment: .leading, spacing: 11) {
                Label(t("section.grid"), systemImage: "square.grid.3x3.fill")
                    .font(.system(size: 13, weight: .semibold))
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 84), spacing: 8)], spacing: 8) {
                    ForEach(StoryboardGrid.availableSides, id: \.self) { side in
                        Button {
                            model.gridSide = side
                        } label: {
                            Text("\(side) × \(side)")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                        }
                        .buttonStyle(GridChoiceStyle(isSelected: model.gridSide == side))
                        .disabled(model.isProcessing)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    Label(t("section.frame"), systemImage: "rectangle.on.rectangle")
                        .font(.system(size: 13, weight: .semibold))
                }
                LazyVGrid(
                    columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible())],
                    spacing: 8
                ) {
                    aspectSelector
                    widthSelector
                }
                .frame(maxWidth: .infinity)
            }

            VStack(alignment: .leading, spacing: 10) {
                Label(t("section.export"), systemImage: "arrow.down.to.line.compact")
                    .font(.system(size: 13, weight: .semibold))
                Text(t("export.autosave"))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Picker(t("export.format"), selection: $model.format) {
                    ForEach(ExportFormat.allCases) { format in
                        Text(format.rawValue).tag(format)
                    }
                }
                .pickerStyle(.segmented)
                .disabled(model.isProcessing)
                LazyVGrid(
                    columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible())],
                    spacing: 8
                ) {
                    Toggle(t("export.time"), isOn: $model.showTimestamps)
                        .font(.system(size: 11, weight: .medium))
                        .toggleStyle(.switch)
                        .compactOptionSurface()
                        .frame(maxWidth: .infinity)
                        .disabled(model.isProcessing)

                    Toggle(t("export.title"), isOn: $model.showTitleWatermark)
                        .font(.system(size: 11, weight: .medium))
                        .toggleStyle(.switch)
                        .compactOptionSurface()
                        .frame(maxWidth: .infinity)
                        .disabled(model.isProcessing)
                }
                .frame(maxWidth: .infinity)
                Text(t("export.local.note"))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
            Button(action: model.generate) {
                HStack(spacing: 9) {
                    if model.isProcessing { ProgressView().controlSize(.small) }
                    Image(systemName: model.isProcessing ? "wand.and.stars.inverse" : "wand.and.stars")
                    Text(model.isProcessing ? model.processingLabel : model.primaryButtonTitle)
                }
                .font(.system(size: 15, weight: .bold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(!model.hasVideos || model.isProcessing)
            .accessibilityLabel(model.isProcessing ? t("accessibility.generating") : t("accessibility.generate"))

            if model.isProcessing {
                Button(t("button.cancel"), role: .cancel, action: model.cancelGeneration)
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                ProgressView(value: model.progress)
                    .tint(Color(red: 0.38, green: 0.82, blue: 0.92))
                    .accessibilityLabel(t("accessibility.analyzing"))
                    .accessibilityValue("\(Int(model.progress * 100))%")
            }
        }
        .padding(24)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(.white.opacity(0.11))
        }
    }

    private var previewPanel: some View {
        VStack(spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text(t("preview.title"))
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundStyle(PreviewText.primary)
                    Text(model.previewStatus)
                        .font(.system(size: 13))
                        .foregroundStyle(PreviewText.secondary)
                }
                Spacer()
            }

            Group {
                if model.isProcessing {
                    ProgressiveStoryboardPreview(
                        gridSide: model.activeGridSide,
                        cardAspectRatio: model.activeCardAspectRatio,
                        language: language,
                        frames: model.livePreviewFrames
                    )
                } else if let image = model.previewImage {
                    VStack(spacing: 16) {
                        Image(nsImage: image)
                            .resizable()
                            .scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .shadow(color: .black.opacity(0.28), radius: 24, y: 12)
                        Button(action: model.exportCurrentResult) {
                            Label(t("button.saveas", (model.renderedFormat ?? model.format).rawValue), systemImage: "square.and.arrow.down")
                                .font(.system(size: 14, weight: .bold))
                                .padding(.horizontal, 18)
                                .padding(.vertical, 10)
                        }
                        .buttonStyle(ExportButtonStyle())
                    }
                } else {
                    EmptyPreview(language: language)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(28)
        .background(Color.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(.white.opacity(0.10))
        }
    }
}

@MainActor
final class StoryboardViewModel: ObservableObject {
    @Published private(set) var videoJobs: [VideoJob] = []
    @Published var language: AppLanguage = .chinese
    @Published var gridSide = 4
    @Published var layoutAspect: StoryboardAspect = .source
    @Published var format: ExportFormat = .png
    @Published var width = 2560
    @Published var showTimestamps = false
    @Published var showTitleWatermark = false
    @Published var previewImage: NSImage?
    @Published var livePreviewFrames: [NSImage] = []
    @Published private(set) var activeGridSide = 4
    @Published private(set) var activeCardAspectRatio = 16.0 / 9.0
    @Published private(set) var activeJobIndex = 0
    @Published private(set) var activeJobCount = 0
    @Published var isProcessing = false
    @Published var progress = 0.0
    @Published var isDropTargeted = false
    @Published var showError = false
    @Published var errorMessage = ""
    @Published var outputDescription = ""
    @Published var renderedFormat: ExportFormat?
    fileprivate var generationTask: Task<Void, Never>?
    private var pendingData: Data?
    private var pendingSource: URL?
    private var pendingFormat: ExportFormat?

    private func t(_ key: String, _ arguments: CVarArg...) -> String {
        language.text(key, arguments: arguments)
    }

    var hasVideos: Bool { !videoJobs.isEmpty }

    var primaryButtonTitle: String {
        videoJobs.count > 1 ? t("button.generate.batch", videoJobs.count) : t("button.generate.single")
    }

    var previewStatus: String {
        if isProcessing {
            let totalFrames = activeGridSide * activeGridSide
            let name = videoJobs.indices.contains(activeJobIndex) ? videoJobs[activeJobIndex].url.lastPathComponent : t("default.video")
            return t("status.processing", activeJobIndex + 1, max(1, activeJobCount), name, livePreviewFrames.count, totalFrames)
        }
        return previewImage == nil ? t("status.empty") : outputDescription
    }

    var processingLabel: String {
        let batchPrefix = activeJobCount > 1 ? "\(activeJobIndex + 1)/\(activeJobCount) · " : ""
        return switch progress {
        case ..<0.58: t("processing.fast", batchPrefix)
        case ..<0.72: t("processing.people", batchPrefix)
        default: t("processing.assembling", batchPrefix)
        }
    }

    func chooseVideo() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.movie]
        panel.allowsOtherFileTypes = true
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        if panel.runModal() == .OK { addVideos(panel.urls) }
    }

    func addVideos(_ urls: [URL]) {
        var knownPaths = Set(videoJobs.map { $0.url.standardizedFileURL.path })
        let candidates = urls
            .map(\.standardizedFileURL)
        let additions = candidates
            .filter(SupportedVideoInput.accepts)
            .filter { knownPaths.insert($0.path).inserted }
            .map { VideoJob(url: $0) }
        videoJobs.append(contentsOf: additions)
        if additions.count < candidates.count {
            errorMessage = t("error.unsupportedInput")
            showError = true
        }
    }

    func clearVideos() {
        guard !isProcessing else { return }
        videoJobs.removeAll()
        previewImage = nil
        livePreviewFrames = []
        outputDescription = ""
    }

    func acceptDrop(providers: [NSItemProvider]) -> Bool {
        guard !isProcessing else { return false }
        let fileProviders = providers.filter { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }
        guard !fileProviders.isEmpty else { return false }
        for provider in fileProviders {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { [weak self] item, _ in
                guard let data = item as? Data,
                      let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
                Task { @MainActor [weak self] in
                    self?.addVideos([url])
                }
            }
        }
        return true
    }

    func generate() {
        guard !videoJobs.isEmpty else { return }
        isProcessing = true
        progress = 0
        let settings = ExportSettings(
            gridSide: gridSide,
            layoutAspect: layoutAspect,
            language: language,
            format: format,
            width: width,
            showTimestamps: showTimestamps,
            showTitleWatermark: showTitleWatermark
        )
        let analyzer = VideoStoryboardAnalyzer()
        let bridge = UIStateBridge(model: self)
        let sourceURLs = videoJobs.map(\.url)
        for index in videoJobs.indices { videoJobs[index].state = .queued }

        let task = Task.detached(priority: .userInitiated) {
            for (index, videoURL) in sourceURLs.enumerated() {
                do {
                    try Task.checkCancellation()
                    await bridge.beginJob(
                        source: videoURL,
                        index: index,
                        total: sourceURLs.count,
                        gridSide: settings.gridSide,
                        layoutAspect: settings.layoutAspect
                    )
                    let result = try await analyzer.analyze(
                        videoURL: videoURL,
                        gridSide: settings.gridSide,
                        outputWidth: settings.safeWidth,
                        progress: { value in
                            bridge.report(progress: value)
                        },
                        onPreviewFrame: { frame, frameIndex, totalFrames in
                            bridge.appendPreview(frame, index: frameIndex, total: totalFrames)
                        }
                    )
                    let data = try StoryboardComposer.render(result: result, settings: settings)
                    await bridge.finishJob(data: data, source: videoURL, settings: settings, index: index, total: sourceURLs.count)
                } catch is CancellationError {
                    await bridge.cancelled()
                    return
                } catch {
                    let message = (error as? StoryboardError)?.message(in: settings.language) ?? error.localizedDescription
                    await bridge.failJob(source: videoURL, index: index, message: message)
                }
            }
            await bridge.finishBatch()
        }
        generationTask = task
    }

    func cancelGeneration() {
        generationTask?.cancel()
        generationTask = nil
        isProcessing = false
        livePreviewFrames = []
        outputDescription = t("status.cancelled")
    }

    private var activeUsesSourceAspect = true

    func beginJob(source: URL, index: Int, total: Int, gridSide: Int, layoutAspect: StoryboardAspect) {
        activeJobIndex = index
        activeJobCount = total
        activeGridSide = gridSide
        activeUsesSourceAspect = layoutAspect == .source
        activeCardAspectRatio = layoutAspect.resolvedCardAspectRatio(sourceAspectRatio: nil)
        livePreviewFrames = []
        progress = 0
        if videoJobs.indices.contains(index) { videoJobs[index].state = .processing }
        outputDescription = t("status.nowProcessing", source.lastPathComponent)
    }

    func appendPreview(_ frame: CapturedFrame, index: Int, total: Int) {
        guard let image = NSImage(data: frame.jpegData) else { return }
        if activeUsesSourceAspect {
            activeCardAspectRatio = StoryboardAspect.source.resolvedCardAspectRatio(sourceAspectRatio: frame.aspectRatio)
        }
        livePreviewFrames.append(image)
        progress = max(progress, 0.72 + 0.26 * Double(index) / Double(max(1, total)))
    }

    func completeJob(data: Data, source: URL, settings: ExportSettings, index: Int, total: Int) {
        previewImage = NSImage(data: data)
        pendingData = data
        pendingSource = source
        pendingFormat = settings.format
        renderedFormat = settings.format
        do {
            let destination = ExportDestination.nextURL(for: source, format: settings.format)
            try data.write(to: destination, options: .atomic)
            if videoJobs.indices.contains(index) { videoJobs[index].state = .completed(destination.lastPathComponent) }
            outputDescription = t("status.saved", index + 1, total, destination.lastPathComponent)
        } catch {
            if videoJobs.indices.contains(index) { videoJobs[index].state = .failed(error.localizedDescription) }
            outputDescription = t("status.generatedNotSaved", index + 1, total)
        }
    }

    func markJobFailed(index: Int, message: String) {
        if videoJobs.indices.contains(index) { videoJobs[index].state = .failed(message) }
        outputDescription = t("status.failedContinue", index + 1)
    }

    func finishBatch() {
        isProcessing = false
        generationTask = nil
        progress = 1
        let completed = videoJobs.filter {
            if case .completed = $0.state { return true }
            return false
        }.count
        let failed = videoJobs.filter {
            if case .failed = $0.state { return true }
            return false
        }.count
        outputDescription = failed > 0
            ? t("status.batchCompletedWithFailures", completed, failed)
            : t("status.batchCompleted", completed)
    }

    func markCancelled() {
        isProcessing = false
        generationTask = nil
        livePreviewFrames = []
        outputDescription = t("status.cancelled")
    }

    func exportCurrentResult() {
        guard let pendingData, let pendingSource, let pendingFormat else { return }
        save(data: pendingData, source: pendingSource, format: pendingFormat)
    }

    func save(data: Data, source: URL, format: ExportFormat) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [format == .png ? .png : .jpeg]
        panel.directoryURL = source.deletingLastPathComponent()
        panel.nameFieldStringValue = ExportDestination.nextURL(for: source, format: format).lastPathComponent
        panel.begin { response in
            guard response == .OK, let destination = panel.url else { return }
            do { try data.write(to: destination, options: .atomic) }
            catch {
                self.errorMessage = error.localizedDescription
                self.showError = true
            }
        }
    }
}

private final class UIStateBridge: @unchecked Sendable {
    weak var model: StoryboardViewModel?

    init(model: StoryboardViewModel) {
        self.model = model
    }

    func report(progress: Double) {
        Task { @MainActor [weak self] in self?.model?.progress = progress }
    }

    func beginJob(
        source: URL,
        index: Int,
        total: Int,
        gridSide: Int,
        layoutAspect: StoryboardAspect
    ) async {
        await MainActor.run { [weak self] in
            self?.model?.beginJob(
                source: source,
                index: index,
                total: total,
                gridSide: gridSide,
                layoutAspect: layoutAspect
            )
        }
    }

    func appendPreview(_ frame: CapturedFrame, index: Int, total: Int) {
        Task { @MainActor [weak self] in
            self?.model?.appendPreview(frame, index: index, total: total)
        }
    }

    func finishJob(data: Data, source: URL, settings: ExportSettings, index: Int, total: Int) async {
        await MainActor.run { [weak self] in
            self?.model?.completeJob(data: data, source: source, settings: settings, index: index, total: total)
        }
    }

    func failJob(source: URL, index: Int, message: String) async {
        await MainActor.run { [weak self] in
            self?.model?.markJobFailed(index: index, message: message)
        }
    }

    func finishBatch() async {
        await MainActor.run { [weak self] in self?.model?.finishBatch() }
    }

    func cancelled() async {
        await MainActor.run { [weak self] in self?.model?.markCancelled() }
    }
}

private struct ShotTesseraMark: View {
    let language: AppLanguage

    var body: some View {
        Group {
            if let image = ShotTesseraIconAsset.image {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .accessibilityLabel(language.text("app.icon.accessibility"))
            } else {
                Image(systemName: "eye")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.indigo, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
        .frame(width: 44, height: 44)
    }
}

private enum ShotTesseraIconAsset {
    static let image: NSImage? = {
        guard let url = Bundle.module.url(forResource: "AppIcon", withExtension: "png") else { return nil }
        return NSImage(contentsOf: url)
    }()
}

private struct VideoBatchCard: View {
    let jobs: [VideoJob]
    let language: AppLanguage
    let isTargeted: Bool
    let isProcessing: Bool
    let choose: () -> Void
    let clear: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Button(action: choose) {
                HStack(spacing: 12) {
                    Image(systemName: jobs.isEmpty ? "film.stack" : "film.fill")
                        .font(.system(size: 19, weight: .medium))
                        .foregroundStyle(Color(red: 0.42, green: 0.85, blue: 0.91))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(title)
                            .font(.system(size: 13, weight: .semibold))
                            .lineLimit(1)
                        Text(subtitle)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.secondary)
                }
                .padding(15)
                .background(Color.white.opacity(isTargeted ? 0.15 : 0.065), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(isTargeted ? Color(red: 0.42, green: 0.85, blue: 0.91) : .white.opacity(0.10), style: StrokeStyle(lineWidth: 1, dash: jobs.isEmpty ? [5, 4] : []))
                }
            }
            .buttonStyle(.plain)
            .disabled(isProcessing)

            if !jobs.isEmpty {
                VStack(spacing: 5) {
                    ForEach(Array(jobs.prefix(3))) { job in
                        HStack(spacing: 7) {
                            Circle()
                                .fill(statusColor(for: job.state))
                                .frame(width: 6, height: 6)
                            Text(job.url.lastPathComponent)
                                .lineLimit(1)
                            Spacer()
                            Text(job.state.label(in: language))
                                .foregroundStyle(.secondary)
                        }
                        .font(.system(size: 10, weight: .medium))
                    }
                    if jobs.count > 3 {
                        Text(language.text("queue.more", jobs.count - 3))
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.horizontal, 4)

                Button(language.text("queue.clear"), action: clear)
                    .font(.system(size: 11, weight: .medium))
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .disabled(isProcessing)
            }
        }
    }

    private var title: String {
        switch jobs.count {
        case 0: language.text("video.add")
        case 1: jobs[0].url.lastPathComponent
        default: language.text("video.added", jobs.count)
        }
    }

    private var subtitle: String {
        jobs.isEmpty ? language.text("video.support") : language.text("video.queueHint")
    }

    private func statusColor(for state: VideoJobState) -> Color {
        switch state {
        case .queued: .secondary
        case .processing: Color(red: 0.42, green: 0.85, blue: 0.91)
        case .completed: .green
        case .failed: .red
        }
    }
}

private struct ProgressiveStoryboardPreview: View {
    let gridSide: Int
    let cardAspectRatio: Double
    let language: AppLanguage
    let frames: [NSImage]

    var body: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: gridSide)
        let safeAspectRatio = min(3, max(1.0 / 3.0, cardAspectRatio))
        VStack(spacing: 12) {
            Text(language.text("preview.live", frames.count, gridSide * gridSide))
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(0..<(gridSide * gridSide), id: \.self) { index in
                    ZStack {
                        if frames.indices.contains(index) {
                            Image(nsImage: frames[index])
                                .resizable()
                                .scaledToFill()
                                .transition(.opacity.combined(with: .scale(scale: 0.94)))
                        } else {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color.white.opacity(index == frames.count ? 0.12 : 0.045))
                            if index == frames.count {
                                ProgressView().controlSize(.mini)
                            }
                        }
                    }
                    .aspectRatio(safeAspectRatio, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
            }
            .aspectRatio(safeAspectRatio, contentMode: .fit)
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.14), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .animation(.easeOut(duration: 0.16), value: frames.count)
    }
}

private struct EmptyPreview: View {
    let language: AppLanguage

    var body: some View {
        VStack(spacing: 18) {
            ShotTesseraMark(language: language).scaleEffect(1.7)
            Text(language.text("preview.empty.title"))
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .foregroundStyle(PreviewText.primary)
            Text(language.text("preview.empty.description"))
                .font(.system(size: 13))
                .foregroundStyle(PreviewText.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 310)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.14), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

private enum PreviewText {
    /// Explicit colors keep the copy readable even when macOS resolves the window as light appearance.
    static let primary = Color(red: 0.84, green: 0.94, blue: 1.00)
    static let secondary = Color(red: 0.62, green: 0.76, blue: 0.91)
}

private struct GridChoiceStyle: ButtonStyle {
    let isSelected: Bool
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(isSelected ? Color(red: 0.06, green: 0.08, blue: 0.11) : .primary)
            .background(isSelected ? Color(red: 0.46, green: 0.87, blue: 0.88) : Color.white.opacity(configuration.isPressed ? 0.14 : 0.06), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(Color(red: 0.04, green: 0.06, blue: 0.08))
            .background(LinearGradient(colors: [Color(red: 0.42, green: 0.87, blue: 0.89), Color(red: 0.64, green: 0.57, blue: 0.96)], startPoint: .leading, endPoint: .trailing), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
            .opacity(configuration.isPressed ? 0.78 : 1)
    }
}

private struct ExportButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.primary)
            .background(Color.white.opacity(configuration.isPressed ? 0.16 : 0.09), in: Capsule())
            .overlay { Capsule().strokeBorder(.white.opacity(0.15)) }
    }
}

private extension View {
    func compactOptionSurface() -> some View {
        padding(.horizontal, 9)
            .frame(height: 34)
            .background(Color.white.opacity(0.065), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .strokeBorder(.white.opacity(0.08))
            }
    }
}
