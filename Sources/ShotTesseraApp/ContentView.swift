import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var model = StoryboardViewModel()

    var body: some View {
        ZStack {
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
        }
        .onDrop(of: [.fileURL], isTargeted: $model.isDropTargeted, perform: model.acceptDrop)
        .alert("无法生成分镜图", isPresented: $model.showError) {
            Button("好", role: .cancel) { }
        } message: {
            Text(model.errorMessage)
        }
    }

    private var controlPanel: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(spacing: 12) {
                ShotTesseraMark()
                VStack(alignment: .leading, spacing: 2) {
                    Text("ShotTessera")
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                    Text("把影片织成一张分镜图")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }

            VideoBatchCard(jobs: model.videoJobs, isTargeted: model.isDropTargeted, isProcessing: model.isProcessing) {
                model.chooseVideo()
            } clear: {
                model.clearVideos()
            }

            VStack(alignment: .leading, spacing: 11) {
                Label("分镜网格", systemImage: "square.grid.3x3.fill")
                    .font(.system(size: 13, weight: .semibold))
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 84), spacing: 8)], spacing: 8) {
                    ForEach(3...9, id: \.self) { side in
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

            VStack(alignment: .leading, spacing: 12) {
                Label("导出", systemImage: "arrow.down.to.line.compact")
                    .font(.system(size: 13, weight: .semibold))
                Text("自动保存到视频同目录：视频名-shot-001；数字自动递增。")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Picker("格式", selection: $model.format) {
                    ForEach(ExportFormat.allCases) { format in
                        Text(format.rawValue).tag(format)
                    }
                }
                .pickerStyle(.segmented)
                .disabled(model.isProcessing)
                Stepper(value: $model.width, in: 1920...12_000, step: 160) {
                    HStack {
                        Text("图像宽度")
                        Spacer()
                        Text("\(model.width) px")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }
                .font(.system(size: 13, weight: .medium))
                .accessibilityHint("输出图片宽度最低为 1920 像素")
                .disabled(model.isProcessing)
                Toggle("显示时间", isOn: $model.showTimestamps)
                    .font(.system(size: 13, weight: .medium))
                    .toggleStyle(.switch)
                    .disabled(model.isProcessing)
                Toggle("添加标题水印", isOn: $model.showTitleWatermark)
                    .font(.system(size: 13, weight: .medium))
                    .toggleStyle(.switch)
                    .disabled(model.isProcessing)
                if model.showTitleWatermark {
                    VStack(alignment: .leading, spacing: 6) {
                        TextField("输入标题，例如：夏日片段", text: $model.watermarkTitle)
                            .textFieldStyle(.roundedBorder)
                            .disabled(model.isProcessing)
                            .accessibilityLabel("水印标题")
                        Text(model.watermarkTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                             ? "输入后会以居中半透明大字写入图片。"
                             : "标题将居中半透明叠加在最终分镜图上。")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
                Text("最低 1920 px；所有画面只在本机处理。")
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
            .accessibilityLabel(model.isProcessing ? "正在生成分镜图" : "一键生成分镜图")

            if model.isProcessing {
                Button("取消生成", role: .cancel, action: model.cancelGeneration)
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                ProgressView(value: model.progress)
                    .tint(Color(red: 0.38, green: 0.82, blue: 0.92))
                    .accessibilityLabel("正在分析影片")
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
                    Text("分镜预览")
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
                    ProgressiveStoryboardPreview(gridSide: model.activeGridSide, frames: model.livePreviewFrames)
                } else if let image = model.previewImage {
                    VStack(spacing: 16) {
                        Image(nsImage: image)
                            .resizable()
                            .scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .shadow(color: .black.opacity(0.28), radius: 24, y: 12)
                        Button(action: model.exportCurrentResult) {
                            Label("另存为 \((model.renderedFormat ?? model.format).rawValue)", systemImage: "square.and.arrow.down")
                                .font(.system(size: 14, weight: .bold))
                                .padding(.horizontal, 18)
                                .padding(.vertical, 10)
                        }
                        .buttonStyle(ExportButtonStyle())
                    }
                } else {
                    EmptyPreview()
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
    @Published var gridSide = 4
    @Published var format: ExportFormat = .png
    @Published var width = 2560
    @Published var showTimestamps = false
    @Published var showTitleWatermark = false
    @Published var watermarkTitle = ""
    @Published var previewImage: NSImage?
    @Published var livePreviewFrames: [NSImage] = []
    @Published private(set) var activeGridSide = 4
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

    var hasVideos: Bool { !videoJobs.isEmpty }

    var primaryButtonTitle: String {
        videoJobs.count > 1 ? "批量生成 \(videoJobs.count) 部分镜图" : "一键生成分镜图"
    }

    var previewStatus: String {
        if isProcessing {
            let totalFrames = activeGridSide * activeGridSide
            let name = videoJobs.indices.contains(activeJobIndex) ? videoJobs[activeJobIndex].url.lastPathComponent : "视频"
            return "第 \(activeJobIndex + 1)/\(max(1, activeJobCount)) 部 · \(name) · 已截取 \(livePreviewFrames.count)/\(totalFrames) 张"
        }
        return previewImage == nil ? "可选择或拖入多个视频，随后按队列自动处理。" : outputDescription
    }

    var processingLabel: String {
        let batchPrefix = activeJobCount > 1 ? "第 \(activeJobIndex + 1)/\(activeJobCount) 部 · " : ""
        return switch progress {
        case ..<0.58: "\(batchPrefix)正在快速浏览画面…"
        case ..<0.72: "\(batchPrefix)正在优选人物镜头…"
        default: "\(batchPrefix)正在实时拼接分镜图…"
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
            errorMessage = "已忽略不是常见视频格式的文件。支持 MP4、MOV、MKV、WebM、AVI、3GP、MPEG、TS 等。"
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
                Task { @MainActor in self?.addVideos([url]) }
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
            format: format,
            width: width,
            showTimestamps: showTimestamps,
            titleWatermark: showTitleWatermark ? watermarkTitle : nil
        )
        let analyzer = VideoStoryboardAnalyzer()
        let bridge = UIStateBridge(model: self)
        let sourceURLs = videoJobs.map(\.url)
        for index in videoJobs.indices { videoJobs[index].state = .queued }

        let task = Task.detached(priority: .userInitiated) {
            for (index, videoURL) in sourceURLs.enumerated() {
                do {
                    try Task.checkCancellation()
                    await bridge.beginJob(source: videoURL, index: index, total: sourceURLs.count, gridSide: settings.gridSide)
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
                    await bridge.failJob(source: videoURL, index: index, message: error.localizedDescription)
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
        outputDescription = "已取消生成。"
    }

    func beginJob(source: URL, index: Int, total: Int, gridSide: Int) {
        activeJobIndex = index
        activeJobCount = total
        activeGridSide = gridSide
        livePreviewFrames = []
        progress = 0
        if videoJobs.indices.contains(index) { videoJobs[index].state = .processing }
        outputDescription = "正在处理 \(source.lastPathComponent)"
    }

    func appendPreview(_ frame: CapturedFrame, index: Int, total: Int) {
        guard let image = NSImage(data: frame.jpegData) else { return }
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
            outputDescription = "第 \(index + 1)/\(total) 部已保存为 \(destination.lastPathComponent)。"
        } catch {
            if videoJobs.indices.contains(index) { videoJobs[index].state = .failed(error.localizedDescription) }
            outputDescription = "第 \(index + 1)/\(total) 部已生成，但未能自动保存。"
        }
    }

    func markJobFailed(index: Int, message: String) {
        if videoJobs.indices.contains(index) { videoJobs[index].state = .failed(message) }
        outputDescription = "第 \(index + 1) 部无法处理，继续下一部。"
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
        outputDescription = "批量处理完成：已保存 \(completed) 部\(failed > 0 ? "，失败 \(failed) 部" : "")。"
    }

    func markCancelled() {
        isProcessing = false
        generationTask = nil
        livePreviewFrames = []
        outputDescription = "已取消生成。"
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

    func beginJob(source: URL, index: Int, total: Int, gridSide: Int) async {
        await MainActor.run { [weak self] in
            self?.model?.beginJob(source: source, index: index, total: total, gridSide: gridSide)
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
    var body: some View {
        Group {
            if let image = ShotTesseraIconAsset.image {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .accessibilityLabel("ShotTessera 拼片之眼图标")
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
                            Text(job.state.label)
                                .foregroundStyle(.secondary)
                        }
                        .font(.system(size: 10, weight: .medium))
                    }
                    if jobs.count > 3 {
                        Text("另有 \(jobs.count - 3) 部影片等待处理")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.horizontal, 4)

                Button("清空队列", action: clear)
                    .font(.system(size: 11, weight: .medium))
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .disabled(isProcessing)
            }
        }
    }

    private var title: String {
        switch jobs.count {
        case 0: "拖入一个或多个视频"
        case 1: jobs[0].url.lastPathComponent
        default: "已添加 \(jobs.count) 部影片"
        }
    }

    private var subtitle: String {
        jobs.isEmpty ? "支持 MP4、MOV、MKV、WebM、AVI、3GP、MPEG、TS 等" : "点击继续添加；将按队列逐部处理"
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
    let frames: [NSImage]

    var body: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: gridSide)
        VStack(spacing: 12) {
            Text("正在实时拼接 · \(frames.count) / \(gridSide * gridSide) 张")
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
                    .aspectRatio(16.0 / 9.0, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.14), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .animation(.easeOut(duration: 0.16), value: frames.count)
    }
}

private struct EmptyPreview: View {
    var body: some View {
        VStack(spacing: 18) {
            ShotTesseraMark().scaleEffect(1.7)
            Text("让影片变成一张图")
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .foregroundStyle(PreviewText.primary)
            Text("自动避开黑屏、模糊与重复画面，优先选择有人物的镜头。")
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
