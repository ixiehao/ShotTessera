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

            VideoDropCard(url: model.videoURL, isTargeted: model.isDropTargeted) {
                model.chooseVideo()
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
                Text("最低 1920 px；所有画面只在本机处理。")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
            Button(action: model.generate) {
                HStack(spacing: 9) {
                    if model.isProcessing { ProgressView().controlSize(.small) }
                    Image(systemName: model.isProcessing ? "wand.and.stars.inverse" : "wand.and.stars")
                    Text(model.isProcessing ? model.processingLabel : "一键生成分镜图")
                }
                .font(.system(size: 15, weight: .bold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(model.videoURL == nil || model.isProcessing)
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
                    Text(model.previewImage == nil ? "选择或拖入视频，然后点“一键生成分镜图”。" : model.outputDescription)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            Group {
                if let image = model.previewImage {
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
    @Published var videoURL: URL?
    @Published var gridSide = 4
    @Published var format: ExportFormat = .png
    @Published var width = 2560
    @Published var previewImage: NSImage?
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

    var processingLabel: String {
        switch progress {
        case ..<0.58: "正在快速浏览画面…"
        case ..<0.72: "正在优选人物镜头…"
        default: "正在生成高清分镜图…"
        }
    }

    func chooseVideo() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.movie]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        if panel.runModal() == .OK { videoURL = panel.url }
    }

    func acceptDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }) else { return false }
        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { [weak self] item, _ in
            guard let data = item as? Data,
                  let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
            Task { @MainActor in self?.videoURL = url }
        }
        return true
    }

    func generate() {
        guard let videoURL else { return }
        isProcessing = true
        progress = 0
        let settings = ExportSettings(gridSide: gridSide, format: format, width: width)
        let analyzer = VideoStoryboardAnalyzer()
        let bridge = UIStateBridge(model: self)

        let task = Task.detached(priority: .userInitiated) {
            do {
                let result = try await analyzer.analyze(
                    videoURL: videoURL,
                    gridSide: settings.gridSide,
                    outputWidth: settings.safeWidth
                ) { value in
                    bridge.report(progress: value)
                }
                let data = try StoryboardComposer.render(result: result, settings: settings)
                bridge.finish(data: data, source: videoURL, settings: settings)
            } catch {
                bridge.fail(with: error.localizedDescription, wasCancelled: error is CancellationError)
            }
        }
        generationTask = task
    }

    func cancelGeneration() {
        generationTask?.cancel()
        generationTask = nil
        isProcessing = false
        outputDescription = "已取消生成。"
    }

    func complete(data: Data, source: URL, settings: ExportSettings) {
        previewImage = NSImage(data: data)
        pendingData = data
        pendingSource = source
        pendingFormat = settings.format
        renderedFormat = settings.format
        isProcessing = false
        generationTask = nil
        do {
            let destination = ExportDestination.nextURL(for: source, format: settings.format)
            try data.write(to: destination, options: .atomic)
            outputDescription = "已生成 \(settings.gridSide) × \(settings.gridSide) 分镜图，已保存为 \(destination.lastPathComponent)。"
        } catch {
            outputDescription = "已生成 \(settings.gridSide) × \(settings.gridSide) 分镜图，但未能自动保存。"
            errorMessage = error.localizedDescription
            showError = true
        }
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

    func finish(data: Data, source: URL, settings: ExportSettings) {
        Task { @MainActor [weak self] in
            guard let model = self?.model else { return }
            model.progress = 1
            model.complete(data: data, source: source, settings: settings)
        }
    }

    func fail(with message: String, wasCancelled: Bool) {
        Task { @MainActor [weak self] in
            guard let model = self?.model else { return }
            model.isProcessing = false
            model.generationTask = nil
            guard !wasCancelled else {
                model.outputDescription = "已取消生成。"
                return
            }
            model.errorMessage = message
            model.showError = true
        }
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

private struct VideoDropCard: View {
    let url: URL?
    let isTargeted: Bool
    let choose: () -> Void

    var body: some View {
        Button(action: choose) {
            HStack(spacing: 12) {
                Image(systemName: url == nil ? "film.stack" : "film.fill")
                    .font(.system(size: 19, weight: .medium))
                    .foregroundStyle(Color(red: 0.42, green: 0.85, blue: 0.91))
                VStack(alignment: .leading, spacing: 3) {
                    Text(url?.lastPathComponent ?? "拖入一个视频")
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                    Text(url == nil ? "MP4、MOV 或 macOS 支持的格式" : "点击更换影片")
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
                    .strokeBorder(isTargeted ? Color(red: 0.42, green: 0.85, blue: 0.91) : .white.opacity(0.10), style: StrokeStyle(lineWidth: 1, dash: url == nil ? [5, 4] : []))
            }
        }
        .buttonStyle(.plain)
    }
}

private struct EmptyPreview: View {
    var body: some View {
        VStack(spacing: 18) {
            ShotTesseraMark().scaleEffect(1.7)
            Text("让影片变成一张图")
                .font(.system(size: 22, weight: .semibold, design: .rounded))
            Text("自动避开黑屏、模糊与重复画面，优先选择有人物的镜头。")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 310)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.14), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
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
