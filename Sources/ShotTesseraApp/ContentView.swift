import AppKit
import SwiftUI
import UniformTypeIdentifiers

private struct ManualFrameEditorRequest: Identifiable {
    let id = UUID()
    let previewID: RenderedStoryboardPreview.ID
    let sourceURL: URL
    let selectionLimit: Int
    let duration: Double
}

struct ContentView: View {
    @StateObject private var model = StoryboardViewModel()
    @EnvironmentObject private var updateChecker: UpdateChecker
    @AppStorage("appLanguage") private var languageCode = AppLanguage.chinese.rawValue
    @State private var isLanguagePickerPresented = false
    @State private var isAspectPickerPresented = false
    @State private var isWidthPickerPresented = false
    @State private var manualFrameEditorRequest: ManualFrameEditorRequest?
    @State private var isPauseConfirmationPresented = false
    @State private var isResumeConfirmationPresented = false
    @State private var isCancelConfirmationPresented = false
    @State private var isFailureReportPresented = false

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

            VStack(spacing: 0) {
                UpdateAvailableBanner(checker: updateChecker, language: language)
                    .padding(.top, 10)
                    .padding(.trailing, 150)
                    .frame(height: updateChecker.hasUpdate ? 48 : 0)

                HStack(spacing: 28) {
                    controlPanel
                        .frame(width: 332)
                    previewPanel
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .padding(30)
                .padding(.top, updateChecker.hasUpdate ? 0 : 18)
            }

            languageMenu
                .padding(.top, 18)
                .padding(.trailing, 22)
        }
        .environment(\.locale, language.locale)
        .onAppear {
            model.language = language
            Task { await updateChecker.checkForUpdate() }
        }
        .onChange(of: languageCode) { newValue in
            model.language = AppLanguage(rawValue: newValue) ?? .chinese
        }
        .onDrop(of: [.fileURL], isTargeted: $model.isDropTargeted, perform: model.acceptDrop)
        .alert(t("alert.generation.title"), isPresented: $model.showError) {
            Button(t("button.ok"), role: .cancel) { }
        } message: {
            Text(model.errorMessage)
        }
        .confirmationDialog(t("alert.pauseBatch.title"), isPresented: $isPauseConfirmationPresented, titleVisibility: .visible) {
            Button(t("button.pauseConfirm")) { model.requestPause() }
            Button(t("button.cancel"), role: .cancel) { }
        } message: {
            Text(t("alert.pauseBatch.message"))
        }
        .confirmationDialog(t("alert.resumeBatch.title"), isPresented: $isResumeConfirmationPresented, titleVisibility: .visible) {
            Button(t("button.resumeConfirm")) { model.resumeGeneration() }
            Button(t("button.cancel"), role: .cancel) { }
        } message: {
            Text(t("alert.resumeBatch.message"))
        }
        .confirmationDialog(t("alert.cancelBatch.title"), isPresented: $isCancelConfirmationPresented, titleVisibility: .visible) {
            Button(t("button.cancelGenerationConfirm"), role: .destructive) { model.cancelGeneration() }
            Button(t("button.keepGenerating"), role: .cancel) { }
        } message: {
            Text(t("alert.cancelBatch.message"))
        }
        .sheet(isPresented: $isFailureReportPresented) {
            BatchFailureReport(
                jobs: model.failedJobs,
                language: language,
                retry: {
                    isFailureReportPresented = false
                    model.retryFailedJobs()
                }
            )
        }
        .sheet(item: $manualFrameEditorRequest) { request in
            ManualFrameEditor(
                model: model,
                sourceURL: request.sourceURL,
                selectionLimit: request.selectionLimit,
                language: language
            ) { frames in
                model.applyManuallySelectedFrames(
                    frames,
                    targetPreviewID: request.previewID,
                    sourceURL: request.sourceURL,
                    duration: request.duration
                )
            }
        }
    }

    private var languageMenu: some View {
        Button {
            isLanguagePickerPresented.toggle()
        } label: {
            HStack(spacing: 7) {
                ProjectIcon(symbol: .language, size: 15)
                    .foregroundStyle(Color(red: 0.48, green: 0.88, blue: 0.93))
                Text(language.displayName)
                    .foregroundStyle(PreviewText.primary)
                ProjectIcon(symbol: .disclosure, size: 10)
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
                                ProjectIcon(symbol: .check, size: 14)
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
                    .minimumScaleFactor(0.8)
                    .allowsTightening(true)
                ProjectIcon(symbol: .selector, size: 11)
                    .foregroundStyle(.secondary)
            }
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .compactOptionSurface()
        .accessibilityLabel(t("section.aspect"))
        .disabled(model.isBusy)
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
                                ProjectIcon(symbol: .check, size: 14)
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
                    .minimumScaleFactor(0.8)
                    .allowsTightening(true)
                ProjectIcon(symbol: .selector, size: 11)
                    .foregroundStyle(.secondary)
            }
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .compactOptionSurface()
        .accessibilityLabel(t("export.width"))
        .disabled(model.isBusy)
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
                                ProjectIcon(symbol: .check, size: 14)
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

            VideoBatchCard(jobs: model.videoJobs, language: language, isTargeted: model.isDropTargeted, isLocked: model.isQueueLocked) {
                model.chooseVideo()
            } clear: {
                model.clearVideos()
            }

            VStack(alignment: .leading, spacing: 11) {
                GlyphLabel(title: t("section.grid"), glyph: .grid)
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
                        .disabled(model.isSettingsLocked)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    GlyphLabel(title: t("section.frame"), glyph: .layers)
                        .font(.system(size: 13, weight: .semibold))
                }
                LazyVGrid(
                    columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible())],
                    spacing: 8
                ) {
                    aspectSelector
                    widthSelector

                    Toggle(t("export.time"), isOn: $model.showTimestamps)
                        .font(.system(size: 11, weight: .medium))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .allowsTightening(true)
                        .toggleStyle(.switch)
                        .tint(SelectionPalette.active)
                        .compactOptionSurface()
                        .disabled(model.isSettingsLocked)

                    Toggle(t("export.title"), isOn: $model.showTitleWatermark)
                        .font(.system(size: 11, weight: .medium))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .allowsTightening(true)
                        .toggleStyle(.switch)
                        .tint(SelectionPalette.active)
                        .compactOptionSurface()
                        .disabled(model.isSettingsLocked)
                }
                .frame(maxWidth: .infinity)
            }

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 7) {
                    GlyphLabel(title: t("section.export"), glyph: .export)
                        .font(.system(size: 13, weight: .semibold))
                    Text(t("export.autosave"))
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                HStack(spacing: 8) {
                    ForEach(ExportFormat.allCases) { format in
                        Button {
                            model.format = format
                        } label: {
                            Text(format.rawValue)
                                .font(.system(size: 12, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                        }
                        .buttonStyle(GridChoiceStyle(isSelected: model.format == format))
                        .disabled(model.isSettingsLocked)
                    }
                }
            }

            Spacer(minLength: 0)
            Button(action: model.generate) {
                HStack(spacing: 9) {
                    if model.isProcessing { ProgressView().controlSize(.small) }
                    ProjectIcon(symbol: .wand, size: 17)
                    Text(model.isProcessing ? model.processingLabel : model.primaryButtonTitle)
                }
                .font(.system(size: 15, weight: .bold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(!model.hasVideos || model.isBusy)
            .accessibilityLabel(model.isProcessing ? t("accessibility.generating") : t("accessibility.generate"))

            if model.isProcessing {
                HStack(spacing: 8) {
                    Button {
                        if model.isPaused {
                            isResumeConfirmationPresented = true
                        } else if !model.isPauseRequested {
                            isPauseConfirmationPresented = true
                        }
                    } label: {
                        GlyphLabel(
                            title: model.isPaused ? t("button.resumeGeneration") : (model.isPauseRequested ? t("button.pausePending") : t("button.pauseGeneration")),
                            glyph: model.isPaused ? .play : .pause,
                            glyphSize: 13
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(ProcessingControlButtonStyle(tone: .primary))
                    .disabled(model.isPauseRequested && !model.isPaused)

                    Button {
                        isCancelConfirmationPresented = true
                    } label: {
                        GlyphLabel(title: t("button.cancelGeneration"), glyph: .trash, glyphSize: 13)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(ProcessingControlButtonStyle(tone: .destructive))
                }
                ProgressView(value: model.progress)
                    .tint(Color(red: 0.38, green: 0.82, blue: 0.92))
                    .accessibilityLabel(t("accessibility.analyzing"))
                    .accessibilityValue("\(Int(model.progress * 100))%")
            }

            if model.hasFailedJobs && !model.isProcessing {
                HStack(spacing: 8) {
                    Button {
                        model.retryFailedJobs()
                    } label: {
                        GlyphLabel(title: t("button.retryFailed", model.failedJobCount), glyph: .refresh, glyphSize: 13)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(ProcessingControlButtonStyle(tone: .primary))

                    Button {
                        isFailureReportPresented = true
                    } label: {
                        GlyphLabel(title: t("button.failureDetails"), glyph: .eye, glyphSize: 13)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(ProcessingControlButtonStyle(tone: .secondary))
                }
            }
        }
        .padding(24)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(.white.opacity(0.11))
        }
    }

    private func previewNavigationButton(
        symbol: ProjectIcon.Symbol,
        label: String,
        enabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            ProjectIcon(symbol: symbol, size: 20)
                .frame(width: 42, height: 42)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(enabled ? Color(red: 0.43, green: 0.85, blue: 0.93) : PreviewText.secondary.opacity(0.32))
        .background(Color.white.opacity(enabled ? 0.08 : 0.035), in: Circle())
        .overlay { Circle().strokeBorder(.white.opacity(enabled ? 0.13 : 0.05)) }
        .disabled(!enabled)
        .accessibilityLabel(label)
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
                    VStack(spacing: 14) {
                        HStack(spacing: 14) {
                            if model.canBrowseCompletedPreviews {
                                previewNavigationButton(
                                    symbol: .previous,
                                    label: t("button.previousResult"),
                                    enabled: model.canShowPreviousPreview && !model.isApplyingFrameAdjustments,
                                    action: model.showPreviousPreview
                                )
                            }

                            Image(nsImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: 660, maxHeight: 470)
                                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                                .shadow(color: .black.opacity(0.28), radius: 24, y: 12)

                            if model.canBrowseCompletedPreviews {
                                previewNavigationButton(
                                    symbol: .next,
                                    label: t("button.nextResult"),
                                    enabled: model.canShowNextPreview && !model.isApplyingFrameAdjustments,
                                    action: model.showNextPreview
                                )
                            }
                        }
                        .frame(maxWidth: .infinity)

                        if model.canBrowseCompletedPreviews {
                            Text(t("preview.position", model.selectedPreviewNumber, model.completedPreviews.count))
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .foregroundStyle(PreviewText.secondary)
                        }

                        HStack(spacing: 10) {
                            if model.lastSavedURL != nil {
                                Button(action: model.revealLastSavedResult) {
                                    GlyphLabel(title: t("button.openSaved"), glyph: .folder)
                                        .font(.system(size: 11, weight: .semibold))
                                        .padding(.horizontal, 11)
                                        .padding(.vertical, 7)
                                }
                                .buttonStyle(SavedResultButtonStyle())
                                .help(t("button.openSaved.hint"))
                            } else {
                                Button(action: model.exportCurrentResult) {
                                    GlyphLabel(title: t("button.saveas", (model.renderedFormat ?? model.format).rawValue), glyph: .save)
                                        .font(.system(size: 12, weight: .semibold))
                                        .padding(.horizontal, 13)
                                        .padding(.vertical, 8)
                                }
                                .buttonStyle(ExportButtonStyle())
                            }

                            if let request = model.manualEditorRequest {
                                Button {
                                    manualFrameEditorRequest = request
                                } label: {
                                    GlyphLabel(title: t("button.adjustFrames"), glyph: .sliders)
                                        .font(.system(size: 14, weight: .bold))
                                        .padding(.horizontal, 18)
                                        .padding(.vertical, 10)
                                        .frame(minWidth: 202)
                                }
                                .buttonStyle(ManualAdjustmentButtonStyle())
                                .help(t("button.adjustFrames.hint"))
                                .accessibilityIdentifier("manual-frame-selection")
                            }
                        }
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

struct RenderedStoryboardPreview: Identifiable {
    let id = UUID()
    let image: NSImage
    let data: Data
    let storyboard: StoryboardResult
    let format: ExportFormat
    var savedURL: URL?
    let jobIndex: Int
    let jobCount: Int
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
    @Published private(set) var activeJobName = ""
    @Published var isProcessing = false
    @Published private(set) var isPauseRequested = false
    @Published private(set) var isPaused = false
    @Published var progress = 0.0
    @Published var isDropTargeted = false
    @Published var showError = false
    @Published var errorMessage = ""
    @Published var outputDescription = ""
    @Published var renderedFormat: ExportFormat?
    @Published private(set) var lastSavedURL: URL?
    @Published private(set) var isApplyingFrameAdjustments = false
    @Published private(set) var completedPreviews: [RenderedStoryboardPreview] = []
    @Published private(set) var selectedPreviewIndex = 0
    fileprivate var generationTask: Task<Void, Never>?
    private var generationRunID = UUID()
    private var generationControl: BatchRunControl?
    private var pendingData: Data?
    private var pendingSource: URL?
    private var pendingFormat: ExportFormat?

    private func t(_ key: String, _ arguments: CVarArg...) -> String {
        language.text(key, arguments: arguments)
    }

    var hasVideos: Bool { !videoJobs.isEmpty }
    var isBusy: Bool { isProcessing || isApplyingFrameAdjustments }
    var isSettingsLocked: Bool { (isProcessing && !isPaused) || isApplyingFrameAdjustments }
    var isQueueLocked: Bool { isProcessing || isApplyingFrameAdjustments }
    var failedJobs: [VideoJob] { videoJobs.filter { $0.state.failureMessage != nil } }
    var failedJobCount: Int { failedJobs.count }
    var hasFailedJobs: Bool { !failedJobs.isEmpty }
    fileprivate var manualEditorRequest: ManualFrameEditorRequest? {
        guard !isBusy, completedPreviews.indices.contains(selectedPreviewIndex) else { return nil }
        let preview = completedPreviews[selectedPreviewIndex]
        return ManualFrameEditorRequest(
            previewID: preview.id,
            sourceURL: preview.storyboard.sourceURL,
            selectionLimit: max(1, preview.storyboard.frames.count),
            duration: preview.storyboard.duration
        )
    }
    var canBrowseCompletedPreviews: Bool { completedPreviews.count > 1 }
    var canShowPreviousPreview: Bool { selectedPreviewIndex > 0 }
    var canShowNextPreview: Bool { selectedPreviewIndex + 1 < completedPreviews.count }
    var selectedPreviewNumber: Int { completedPreviews.isEmpty ? 0 : selectedPreviewIndex + 1 }
    var primaryButtonTitle: String {
        videoJobs.count > 1 ? t("button.generate.batch", videoJobs.count) : t("button.generate.single")
    }

    var previewStatus: String {
        if isPaused { return outputDescription }
        if isPauseRequested { return t("status.pausePending") }
        if isProcessing {
            let totalFrames = activeGridSide * activeGridSide
            let name = activeJobName.isEmpty ? t("default.video") : activeJobName
            return t("status.processing", activeJobIndex + 1, max(1, activeJobCount), name, livePreviewFrames.count, totalFrames)
        }
        return previewImage == nil ? t("status.empty") : outputDescription
    }

    var processingLabel: String {
        if isPaused { return t("processing.paused") }
        if isPauseRequested { return t("processing.pausePending") }
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
        guard !isBusy else { return }
        var knownPaths = Set(videoJobs.map { $0.url.standardizedFileURL.path })
        let candidates = urls
            .map(\.standardizedFileURL)
        let supported = candidates.filter(SupportedVideoInput.accepts)
        let additions = supported
            .filter { knownPaths.insert($0.path).inserted }
            .map { VideoJob(url: $0) }
        videoJobs.append(contentsOf: additions)
        if supported.count < candidates.count {
            errorMessage = t("error.unsupportedInput")
            showError = true
        }
    }

    func clearVideos() {
        guard !isBusy else { return }
        videoJobs.removeAll()
        previewImage = nil
        livePreviewFrames = []
        outputDescription = ""
        lastSavedURL = nil
        pendingData = nil
        pendingSource = nil
        pendingFormat = nil
        completedPreviews = []
        selectedPreviewIndex = 0
    }

    func acceptDrop(providers: [NSItemProvider]) -> Bool {
        guard !isBusy else { return false }
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
        guard !videoJobs.isEmpty, !isBusy else { return }
        startGeneration(indices: Array(videoJobs.indices), resetPreviews: true)
    }

    func retryFailedJobs() {
        guard !isBusy else { return }
        let indices = videoJobs.indices.filter { videoJobs[$0].state.failureMessage != nil }
        guard !indices.isEmpty else { return }
        for index in indices { videoJobs[index].state = .queued }
        startGeneration(indices: indices, resetPreviews: false)
    }

    func requestPause() {
        guard isProcessing, !isPauseRequested, !isPaused, let generationControl else { return }
        isPauseRequested = true
        Task { await generationControl.requestPause() }
    }

    func resumeGeneration() {
        guard isProcessing, isPaused, let generationControl else { return }
        isPaused = false
        isPauseRequested = false
        Task { await generationControl.resume() }
    }

    private func startGeneration(indices: [Int], resetPreviews: Bool) {
        guard !indices.isEmpty else { return }
        let runID = UUID()
        generationRunID = runID
        isProcessing = true
        isPauseRequested = false
        isPaused = false
        progress = 0
        lastSavedURL = nil
        pendingData = nil
        pendingSource = nil
        pendingFormat = nil
        if resetPreviews {
            completedPreviews = []
            selectedPreviewIndex = 0
        }
        let analyzer = VideoStoryboardAnalyzer()
        let bridge = UIStateBridge(model: self, generationRunID: runID)
        let selectedJobs = indices.compactMap { index -> (index: Int, url: URL)? in
            guard videoJobs.indices.contains(index) else { return nil }
            return (index, videoJobs[index].url)
        }
        guard !selectedJobs.isEmpty else {
            isProcessing = false
            return
        }
        let control = BatchRunControl()
        generationControl = control
        for index in selectedJobs.map(\.index) { videoJobs[index].state = .queued }

        let task = Task.detached(priority: .userInitiated) {
            for (batchIndex, job) in selectedJobs.enumerated() {
                var settings: ExportSettings?
                do {
                    if await control.isPauseRequested() {
                        await bridge.pauseBatch()
                        await control.waitUntilResumed()
                        try Task.checkCancellation()
                        await bridge.resumeBatch()
                    }
                    try Task.checkCancellation()
                    guard let currentSettings = await bridge.currentGenerationSettings() else { return }
                    settings = currentSettings
                    await bridge.beginJob(
                        source: job.url,
                        jobIndex: job.index,
                        batchIndex: batchIndex,
                        total: selectedJobs.count,
                        gridSide: currentSettings.gridSide,
                        layoutAspect: currentSettings.layoutAspect
                    )
                    let result = try await analyzer.analyze(
                        videoURL: job.url,
                        gridSide: currentSettings.gridSide,
                        outputWidth: currentSettings.safeWidth,
                        progress: { value in
                            bridge.report(progress: value)
                        },
                        onPreviewFrame: { frame, frameIndex, totalFrames in
                            bridge.appendPreview(frame, index: frameIndex, total: totalFrames)
                        }
                    )
                    let data = try StoryboardComposer.render(result: result, settings: currentSettings)
                    await bridge.finishJob(data: data, result: result, settings: currentSettings, index: job.index, total: selectedJobs.count)
                } catch is CancellationError {
                    await bridge.cancelled()
                    return
                } catch {
                    let language: AppLanguage
                    if let settings {
                        language = settings.language
                    } else {
                        language = await bridge.currentLanguage()
                    }
                    let message = (error as? StoryboardError)?.message(in: language) ?? error.localizedDescription
                    await bridge.failJob(index: job.index, message: message)
                }
            }
            await bridge.finishBatch()
        }
        generationTask = task
    }

    func cancelGeneration() {
        let control = generationControl
        generationRunID = UUID()
        generationTask?.cancel()
        generationTask = nil
        generationControl = nil
        isProcessing = false
        isPauseRequested = false
        isPaused = false
        for index in videoJobs.indices where videoJobs[index].state == .processing {
            videoJobs[index].state = .queued
        }
        livePreviewFrames = []
        outputDescription = t("status.cancelled")
        Task { await control?.resume() }
    }

    fileprivate func generationSettings() -> ExportSettings {
        ExportSettings(
            gridSide: gridSide,
            layoutAspect: layoutAspect,
            language: language,
            format: format,
            width: width,
            showTimestamps: showTimestamps,
            showTitleWatermark: showTitleWatermark
        )
    }

    fileprivate func markPausedAtCheckpoint() {
        isPaused = true
        isPauseRequested = false
        livePreviewFrames = []
        outputDescription = t("status.paused")
    }

    fileprivate func markResumedAtCheckpoint() {
        isPaused = false
        isPauseRequested = false
    }

    private var activeUsesSourceAspect = true

    func beginJob(source: URL, jobIndex: Int, batchIndex: Int, total: Int, gridSide: Int, layoutAspect: StoryboardAspect) {
        activeJobIndex = batchIndex
        activeJobCount = total
        activeJobName = source.lastPathComponent
        activeGridSide = gridSide
        activeUsesSourceAspect = layoutAspect == .source
        activeCardAspectRatio = layoutAspect.resolvedCardAspectRatio(sourceAspectRatio: nil)
        livePreviewFrames = []
        progress = 0
        if videoJobs.indices.contains(jobIndex) { videoJobs[jobIndex].state = .processing }
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

    func completeJob(data: Data, result: StoryboardResult, settings: ExportSettings, index: Int, total: Int) {
        guard let image = NSImage(data: data) else {
            markJobFailed(index: index, message: t("error.noExportData"))
            return
        }
        var savedURL: URL?
        do {
            let destination = ExportDestination.nextURL(for: result.sourceURL, format: settings.format)
            try data.write(to: destination, options: .atomic)
            if videoJobs.indices.contains(index) { videoJobs[index].state = .completed(destination.lastPathComponent) }
            savedURL = destination
        } catch {
            if videoJobs.indices.contains(index) { videoJobs[index].state = .failed(error.localizedDescription) }
        }

        completedPreviews.append(
            RenderedStoryboardPreview(
                image: image,
                data: data,
                storyboard: result,
                format: settings.format,
                savedURL: savedURL,
                jobIndex: index,
                jobCount: total
            )
        )
        selectPreview(at: completedPreviews.count - 1)
        if savedURL == nil {
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
        generationControl = nil
        isPauseRequested = false
        isPaused = false
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
        generationControl = nil
        isPauseRequested = false
        isPaused = false
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
            do {
                try data.write(to: destination, options: .atomic)
                self.lastSavedURL = destination
                if self.completedPreviews.indices.contains(self.selectedPreviewIndex) {
                    self.completedPreviews[self.selectedPreviewIndex].savedURL = destination
                }
                self.outputDescription = self.t("status.manualSaved", destination.lastPathComponent)
            }
            catch {
                self.errorMessage = error.localizedDescription
                self.showError = true
            }
        }
    }

    func revealLastSavedResult() {
        guard let lastSavedURL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([lastSavedURL])
    }

    func showPreviousPreview() {
        selectPreview(at: selectedPreviewIndex - 1)
    }

    func showNextPreview() {
        selectPreview(at: selectedPreviewIndex + 1)
    }

    func applyManuallySelectedFrames(
        _ frames: [CapturedFrame],
        targetPreviewID: RenderedStoryboardPreview.ID,
        sourceURL: URL,
        duration: Double
    ) {
        guard !frames.isEmpty, !isApplyingFrameAdjustments else { return }
        let updatedResult = StoryboardResult(
            frames: frames,
            sourceURL: sourceURL,
            duration: duration
        )
        let settings = ExportSettings(
            gridSide: gridSide,
            layoutAspect: layoutAspect,
            language: language,
            format: format,
            width: width,
            showTimestamps: showTimestamps,
            showTitleWatermark: showTitleWatermark
        )
        isApplyingFrameAdjustments = true
        let bridge = UIStateBridge(model: self)

        Task.detached(priority: .userInitiated) {
            do {
                let data = try StoryboardComposer.render(result: updatedResult, settings: settings)
                await bridge.finishEditedFrames(
                    data: data,
                    result: updatedResult,
                    settings: settings,
                    targetPreviewID: targetPreviewID
                )
            } catch {
                await bridge.failEditedFrames(
                    message: (error as? StoryboardError)?.message(in: settings.language) ?? error.localizedDescription
                )
            }
        }
    }

    fileprivate func completeEditedFrames(
        data: Data,
        result: StoryboardResult,
        settings: ExportSettings,
        targetPreviewID: RenderedStoryboardPreview.ID
    ) {
        defer { isApplyingFrameAdjustments = false }
        guard let image = NSImage(data: data) else {
            outputDescription = t("status.generatedNotSaved", 1, 1)
            return
        }
        guard let targetIndex = completedPreviews.firstIndex(where: { $0.id == targetPreviewID }) else {
            return
        }
        var savedURL: URL?
        do {
            let destination = ExportDestination.nextURL(for: result.sourceURL, format: settings.format)
            try data.write(to: destination, options: .atomic)
            savedURL = destination
            if let jobIndex = videoJobs.firstIndex(where: { $0.url.standardizedFileURL == result.sourceURL.standardizedFileURL }) {
                videoJobs[jobIndex].state = .completed(destination.lastPathComponent)
            }
        } catch {
            savedURL = nil
        }

        let existing = completedPreviews[targetIndex]
        let updated = RenderedStoryboardPreview(
            image: image,
            data: data,
            storyboard: result,
            format: settings.format,
            savedURL: savedURL,
            jobIndex: existing.jobIndex,
            jobCount: existing.jobCount
        )
        completedPreviews[targetIndex] = updated
        if selectedPreviewIndex == targetIndex {
            selectPreview(at: targetIndex)
            if let savedURL {
                outputDescription = t("status.manualSaved", savedURL.lastPathComponent)
            } else {
                outputDescription = t("status.generatedNotSaved", 1, 1)
            }
        }
    }

    fileprivate func markFrameEditFailed(_ message: String) {
        isApplyingFrameAdjustments = false
        errorMessage = message
        showError = true
    }

    private func selectPreview(at index: Int) {
        guard completedPreviews.indices.contains(index) else { return }
        selectedPreviewIndex = index
        let preview = completedPreviews[index]
        previewImage = preview.image
        pendingData = preview.data
        pendingSource = preview.storyboard.sourceURL
        pendingFormat = preview.format
        renderedFormat = preview.format
        lastSavedURL = preview.savedURL
        if let savedURL = preview.savedURL {
            outputDescription = t("status.saved", preview.jobIndex + 1, preview.jobCount, savedURL.lastPathComponent)
        } else {
            outputDescription = t("status.generatedNotSaved", preview.jobIndex + 1, preview.jobCount)
        }
    }

    fileprivate func acceptsGenerationUpdate(for runID: UUID?) -> Bool {
        runID == nil || runID == generationRunID
    }
}

private final class UIStateBridge: @unchecked Sendable {
    weak var model: StoryboardViewModel?
    private let generationRunID: UUID?

    init(model: StoryboardViewModel, generationRunID: UUID? = nil) {
        self.model = model
        self.generationRunID = generationRunID
    }

    @MainActor
    private func acceptsCurrentGeneration(_ model: StoryboardViewModel) -> Bool {
        model.acceptsGenerationUpdate(for: generationRunID)
    }

    func report(progress: Double) {
        Task { @MainActor [weak self] in
            guard let self, let model = self.model, self.acceptsCurrentGeneration(model) else { return }
            model.progress = progress
        }
    }

    func beginJob(
        source: URL,
        jobIndex: Int,
        batchIndex: Int,
        total: Int,
        gridSide: Int,
        layoutAspect: StoryboardAspect
    ) async {
        await MainActor.run { [weak self] in
            guard let self, let model = self.model, self.acceptsCurrentGeneration(model) else { return }
            model.beginJob(
                source: source,
                jobIndex: jobIndex,
                batchIndex: batchIndex,
                total: total,
                gridSide: gridSide,
                layoutAspect: layoutAspect
            )
        }
    }

    func appendPreview(_ frame: CapturedFrame, index: Int, total: Int) {
        Task { @MainActor [weak self] in
            guard let self, let model = self.model, self.acceptsCurrentGeneration(model) else { return }
            model.appendPreview(frame, index: index, total: total)
        }
    }

    func finishJob(data: Data, result: StoryboardResult, settings: ExportSettings, index: Int, total: Int) async {
        await MainActor.run { [weak self] in
            guard let self, let model = self.model, self.acceptsCurrentGeneration(model) else { return }
            model.completeJob(data: data, result: result, settings: settings, index: index, total: total)
        }
    }

    func failJob(index: Int, message: String) async {
        await MainActor.run { [weak self] in
            guard let self, let model = self.model, self.acceptsCurrentGeneration(model) else { return }
            model.markJobFailed(index: index, message: message)
        }
    }

    func currentGenerationSettings() async -> ExportSettings? {
        await MainActor.run { [weak self] in
            guard let self, let model = self.model, self.acceptsCurrentGeneration(model) else { return nil }
            return model.generationSettings()
        }
    }

    func currentLanguage() async -> AppLanguage {
        await MainActor.run { [weak self] in
            self?.model?.language ?? .chinese
        }
    }

    func pauseBatch() async {
        await MainActor.run { [weak self] in
            guard let self, let model = self.model, self.acceptsCurrentGeneration(model) else { return }
            model.markPausedAtCheckpoint()
        }
    }

    func resumeBatch() async {
        await MainActor.run { [weak self] in
            guard let self, let model = self.model, self.acceptsCurrentGeneration(model) else { return }
            model.markResumedAtCheckpoint()
        }
    }

    func finishBatch() async {
        await MainActor.run { [weak self] in
            guard let self, let model = self.model, self.acceptsCurrentGeneration(model) else { return }
            model.finishBatch()
        }
    }

    func cancelled() async {
        await MainActor.run { [weak self] in
            guard let self, let model = self.model, self.acceptsCurrentGeneration(model) else { return }
            model.markCancelled()
        }
    }

    func finishEditedFrames(
        data: Data,
        result: StoryboardResult,
        settings: ExportSettings,
        targetPreviewID: RenderedStoryboardPreview.ID
    ) async {
        await MainActor.run { [weak self] in
            self?.model?.completeEditedFrames(
                data: data,
                result: result,
                settings: settings,
                targetPreviewID: targetPreviewID
            )
        }
    }

    func failEditedFrames(message: String) async {
        await MainActor.run { [weak self] in
            self?.model?.markFrameEditFailed(message)
        }
    }
}

private struct ManualFrameEditor: View {
    @ObservedObject var model: StoryboardViewModel
    let sourceURL: URL
    let selectionLimit: Int
    let language: AppLanguage
    let onApply: ([CapturedFrame]) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var candidates: [CapturedFrame] = []
    @State private var selectedIDs = Set<Int>()
    @State private var candidateBatch = 0
    @State private var isLoadingCandidates = false
    @State private var isSmartSelecting = false
    @State private var captureToken = UUID()
    @State private var captureError = ""
    @State private var candidateSamplingTask: Task<[CapturedFrame], Error>?
    @State private var candidatePresentationTask: Task<Void, Never>?
    @State private var smartSelectionTask: Task<[Int], Never>?
    @State private var smartSelectionPresentationTask: Task<Void, Never>?

    private func t(_ key: String, _ arguments: CVarArg...) -> String {
        language.text(key, arguments: arguments)
    }

    private var selectedFrames: [CapturedFrame] {
        candidates
            .filter { selectedIDs.contains($0.id) }
            .sorted { $0.time < $1.time }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 5) {
                Text(t("editor.title"))
                    .font(.system(size: 21, weight: .bold, design: .rounded))
                Text(t("editor.detail"))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            HStack {
                GlyphLabel(title: t("editor.selectionCount", selectedIDs.count, selectionLimit), glyph: .selected)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(selectedIDs.count == selectionLimit ? .green : .secondary)
                Spacer()
                Button(action: smartSelectCandidates) {
                    if isSmartSelecting {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        GlyphLabel(title: t("editor.smartSelect"), glyph: .wand)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(red: 0.18, green: 0.54, blue: 0.78))
                .disabled(isLoadingCandidates || candidates.isEmpty || isSmartSelecting)
                .accessibilityIdentifier("manual-frame-smart-select")
                Button(action: regenerateCandidates) {
                    GlyphLabel(title: t("editor.regenerate"), glyph: .refresh)
                }
                .buttonStyle(.bordered)
                .disabled(isLoadingCandidates || isSmartSelecting)
                .accessibilityIdentifier("manual-frame-regenerate")
            }

            ScrollView {
                if isLoadingCandidates {
                    ProgressView(t("editor.loading"))
                        .frame(maxWidth: .infinity, minHeight: 360)
                } else if candidates.isEmpty {
                    VStack(spacing: 8) {
                        ProjectIcon(symbol: .film, size: 28)
                            .foregroundStyle(.secondary)
                        Text(captureError.isEmpty ? t("editor.noPreview") : captureError)
                            .font(.system(size: 12))
                            .foregroundStyle(captureError.isEmpty ? Color.secondary : Color.red)
                    }
                    .frame(maxWidth: .infinity, minHeight: 360)
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 116), spacing: 8)], spacing: 8) {
                        ForEach(candidates) { candidate in
                            Button {
                                toggle(candidate)
                            } label: {
                                frameImage(candidate)
                                    .frame(height: 88)
                                    .overlay(alignment: .bottomLeading) {
                                        Text(TimestampFormatter.string(for: candidate.time))
                                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                                            .padding(.horizontal, 5)
                                            .padding(.vertical, 3)
                                            .foregroundStyle(.white)
                                            .background(.black.opacity(0.65), in: Capsule())
                                            .padding(5)
                                    }
                                    .overlay(alignment: .topTrailing) {
                                        if selectedIDs.contains(candidate.id) {
                                            ProjectIcon(symbol: .selected, size: 20)
                                                .foregroundStyle(Color(red: 0.34, green: 0.84, blue: 0.92))
                                                .shadow(color: .black.opacity(0.38), radius: 3)
                                                .padding(5)
                                        }
                                    }
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .strokeBorder(
                                                selectedIDs.contains(candidate.id)
                                                    ? Color(red: 0.34, green: 0.84, blue: 0.92)
                                                    : .white.opacity(0.10),
                                                lineWidth: selectedIDs.contains(candidate.id) ? 3 : 1
                                            )
                                    }
                            }
                            .buttonStyle(.plain)
                            .disabled(!selectedIDs.contains(candidate.id) && selectedIDs.count >= selectionLimit)
                        }
                    }
                }
            }
            .frame(minHeight: 340, maxHeight: 450)
            .accessibilityIdentifier("manual-frame-candidates")

            HStack {
                Button(t("editor.cancel"), role: .cancel) { dismiss() }
                Spacer()
                Button {
                    onApply(selectedFrames)
                    dismiss()
                } label: {
                    GlyphLabel(title: t("editor.apply"), glyph: .check)
                        .font(.system(size: 13, weight: .bold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedIDs.count != selectionLimit || model.isApplyingFrameAdjustments)
                .accessibilityIdentifier("manual-frame-apply")
            }
        }
        .padding(24)
        .frame(minWidth: 820, minHeight: 610)
        .accessibilityIdentifier("manual-frame-editor")
        .onAppear { loadCandidates() }
        .onDisappear(perform: cancelBackgroundWork)
    }

    @ViewBuilder
    private func frameImage(_ frame: CapturedFrame) -> some View {
        if let image = NSImage(data: frame.jpegData) {
            Image(nsImage: image)
                .resizable()
                .scaledToFill()
                .aspectRatio(frame.aspectRatio, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        } else {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(.quaternary)
                .aspectRatio(frame.aspectRatio, contentMode: .fit)
        }
    }

    private func toggle(_ candidate: CapturedFrame) {
        if selectedIDs.contains(candidate.id) {
            selectedIDs.remove(candidate.id)
        } else if selectedIDs.count < selectionLimit {
            selectedIDs.insert(candidate.id)
        }
    }

    private func regenerateCandidates() {
        candidateBatch += 1
        selectedIDs.removeAll()
        loadCandidates()
    }

    private func smartSelectCandidates() {
        guard !candidates.isEmpty, !isSmartSelecting else { return }
        let token = captureToken
        let source = candidates
        let targetCount = selectionLimit
        isSmartSelecting = true

        smartSelectionTask?.cancel()
        smartSelectionPresentationTask?.cancel()
        let selectionTask = Task.detached(priority: .userInitiated) {
            ManualFrameSelector.selectIDs(from: source, count: targetCount)
        }
        smartSelectionTask = selectionTask
        smartSelectionPresentationTask = Task {
            let ids = await selectionTask.value
            guard !Task.isCancelled, token == captureToken else { return }
            selectedIDs = Set(ids)
            isSmartSelecting = false
            smartSelectionTask = nil
            smartSelectionPresentationTask = nil
        }
    }

    private func loadCandidates() {
        candidateSamplingTask?.cancel()
        candidatePresentationTask?.cancel()
        let token = UUID()
        captureToken = token
        captureError = ""
        isLoadingCandidates = true
        isSmartSelecting = false
        let outputWidth = model.width
        let gridSide = max(1, Int(Double(selectionLimit).squareRoot().rounded()))
        let requestedCount = min(72, max(24, selectionLimit * 3))
        let batch = candidateBatch

        // Sampling candidates may decode dozens of frames. Keep that work off the
        // main actor so scrolling, selection and the progress state stay responsive.
        let samplingTask = Task.detached(priority: .userInitiated) {
            try await ManualFrameExtractor.captureCandidates(
                from: sourceURL,
                gridSide: gridSide,
                outputWidth: outputWidth,
                count: requestedCount,
                batch: batch
            )
        }
        candidateSamplingTask = samplingTask

        candidatePresentationTask = Task {
            do {
                let frames = try await samplingTask.value
                guard !Task.isCancelled, token == captureToken else { return }
                candidates = frames
            } catch {
                guard !Task.isCancelled, token == captureToken else { return }
                captureError = (error as? StoryboardError)?.message(in: language) ?? error.localizedDescription
            }
            guard !Task.isCancelled, token == captureToken else { return }
            isLoadingCandidates = false
            candidateSamplingTask = nil
            candidatePresentationTask = nil
        }
    }

    private func cancelBackgroundWork() {
        captureToken = UUID()
        candidateSamplingTask?.cancel()
        candidatePresentationTask?.cancel()
        smartSelectionTask?.cancel()
        smartSelectionPresentationTask?.cancel()
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
                ProjectIcon(symbol: .eye, size: 22)
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

private struct ProcessingControlButtonStyle: ButtonStyle {
    enum Tone {
        case primary
        case secondary
        case destructive
    }

    let tone: Tone

    func makeBody(configuration: Configuration) -> some View {
        let colors: (fill: Color, stroke: Color, text: Color) = switch tone {
        case .primary:
            (Color(red: 0.12, green: 0.38, blue: 0.54).opacity(0.80), Color(red: 0.36, green: 0.82, blue: 0.92).opacity(0.72), .white)
        case .secondary:
            (Color.white.opacity(0.075), Color.white.opacity(0.16), PreviewText.primary)
        case .destructive:
            (Color(red: 0.48, green: 0.10, blue: 0.16).opacity(0.82), Color(red: 1.0, green: 0.42, blue: 0.46).opacity(0.75), .white)
        }
        return configuration.label
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(colors.text)
            .background(colors.fill.opacity(configuration.isPressed ? 0.68 : 1), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(colors.stroke)
            }
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private struct BatchFailureReport: View {
    let jobs: [VideoJob]
    let language: AppLanguage
    let retry: () -> Void
    @Environment(\.dismiss) private var dismiss

    private func t(_ key: String, _ arguments: CVarArg...) -> String {
        language.text(key, arguments: arguments)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 5) {
                Text(t("failureReport.title"))
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                Text(t("failureReport.detail", jobs.count))
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }

            List(jobs) { job in
                VStack(alignment: .leading, spacing: 4) {
                    Text(job.url.lastPathComponent)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                    Text(job.state.failureMessage ?? t("failureReport.unknown"))
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
                .padding(.vertical, 3)
            }
            .frame(minHeight: 180, idealHeight: 300)

            HStack {
                Button(t("button.close")) { dismiss() }
                Spacer()
                Button(action: retry) {
                    GlyphLabel(title: t("button.retryFailed", jobs.count), glyph: .refresh)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(22)
        .frame(width: 560, height: 450)
    }
}

private struct VideoBatchCard: View {
    let jobs: [VideoJob]
    let language: AppLanguage
    let isTargeted: Bool
    let isLocked: Bool
    let choose: () -> Void
    let clear: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Button(action: choose) {
                HStack(spacing: 12) {
                    ProjectIcon(symbol: jobs.isEmpty ? .filmStack : .film, size: 19)
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
                    ProjectIcon(symbol: .plus, size: 14)
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
            .disabled(isLocked)

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
                        HStack(spacing: 8) {
                            Text(language.text("queue.more", jobs.count - 3))
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                            Spacer(minLength: 0)
                            clearQueueButton
                        }
                    }
                }
                .padding(.horizontal, 4)

                if jobs.count <= 3 {
                    HStack {
                        Spacer()
                        clearQueueButton
                    }
                    .padding(.horizontal, 4)
                }
            }
        }
    }

    private var clearQueueButton: some View {
        Button(action: clear) {
            GlyphLabel(title: language.text("queue.clear"), glyph: .trash)
                .font(.system(size: 10, weight: .bold))
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
        .background(Color(red: 0.80, green: 0.18, blue: 0.24), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color.white.opacity(0.22))
        }
        .shadow(color: Color.red.opacity(0.18), radius: 3, y: 1)
        .help(language.text("queue.clear.hint"))
        .disabled(isLocked)
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

private enum SelectionPalette {
    /// The single active-state color used by grid, format, and switch controls.
    static let active = Color(red: 0.46, green: 0.87, blue: 0.88)
}

private struct GridChoiceStyle: ButtonStyle {
    let isSelected: Bool
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(isSelected ? Color(red: 0.06, green: 0.08, blue: 0.11) : .primary)
            .background(isSelected ? SelectionPalette.active : Color.white.opacity(configuration.isPressed ? 0.14 : 0.06), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
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

private struct SavedResultButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(Color(red: 0.04, green: 0.11, blue: 0.16))
            .background(
                LinearGradient(
                    colors: [Color(red: 0.39, green: 0.86, blue: 0.89), Color(red: 0.50, green: 0.72, blue: 0.98)],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                in: Capsule()
            )
            .overlay { Capsule().strokeBorder(.white.opacity(0.28)) }
            .shadow(color: Color(red: 0.30, green: 0.75, blue: 0.94).opacity(0.24), radius: 10, y: 4)
            .opacity(configuration.isPressed ? 0.78 : 1)
    }
}

private struct ManualAdjustmentButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(Color(red: 0.88, green: 0.96, blue: 1.00))
            .background(
                LinearGradient(
                    colors: [
                        Color(red: 0.10, green: 0.31, blue: 0.44),
                        Color(red: 0.17, green: 0.27, blue: 0.51)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                in: Capsule()
            )
            .overlay { Capsule().strokeBorder(Color(red: 0.42, green: 0.84, blue: 0.96).opacity(0.72)) }
            .shadow(color: Color(red: 0.25, green: 0.68, blue: 0.91).opacity(configuration.isPressed ? 0.08 : 0.18), radius: 8, y: 3)
            .opacity(configuration.isPressed ? 0.80 : 1)
    }
}

private extension View {
    func compactOptionSurface() -> some View {
        padding(.horizontal, 9)
            .frame(maxWidth: .infinity, minHeight: 34, maxHeight: 34)
            .background(Color.white.opacity(0.065), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .strokeBorder(.white.opacity(0.08))
            }
    }
}
