import AppKit
import CoreImage

enum InstallerBackgroundError: Error {
    case invalidArguments
    case unreadableImage(String)
    case missingGraphicsContext
    case unableToWrite(String)
}

let arguments = CommandLine.arguments
guard arguments.count == 3 else {
    throw InstallerBackgroundError.invalidArguments
}

let sourceURL = URL(fileURLWithPath: arguments[1])
let outputURL = URL(fileURLWithPath: arguments[2])
let canvasSize = NSSize(width: 1280, height: 720)

guard let sourceImage = CIImage(contentsOf: sourceURL) else {
    throw InstallerBackgroundError.unreadableImage(sourceURL.path)
}

func cover(_ image: CIImage, in size: NSSize) -> CIImage {
    let sourceExtent = image.extent
    let scale = max(size.width / sourceExtent.width, size.height / sourceExtent.height)
    let scaled = image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
    let x = (size.width - scaled.extent.width) / 2
    let y = (size.height - scaled.extent.height) / 2
    return scaled.transformed(by: CGAffineTransform(translationX: x, y: y))
}

let canvasRect = CGRect(origin: .zero, size: canvasSize)
let blurredSource = cover(sourceImage, in: canvasSize)
    .clampedToExtent()
    .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: 26])
    .cropped(to: canvasRect)
let ciContext = CIContext(options: [.useSoftwareRenderer: false])
guard let backgroundCGImage = ciContext.createCGImage(blurredSource, from: canvasRect) else {
    throw InstallerBackgroundError.unreadableImage(sourceURL.path)
}

guard let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: Int(canvasSize.width),
    pixelsHigh: Int(canvasSize.height),
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
), let nsGraphicsContext = NSGraphicsContext(bitmapImageRep: bitmap) else {
    throw InstallerBackgroundError.missingGraphicsContext
}
bitmap.size = canvasSize
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = nsGraphicsContext
guard let graphicsContext = NSGraphicsContext.current?.cgContext else {
    throw InstallerBackgroundError.missingGraphicsContext
}

graphicsContext.draw(backgroundCGImage, in: canvasRect)
// A quiet, glassy surface keeps the reference imagery recognisable without
// competing with Finder's real application and Applications icons.
NSColor(calibratedRed: 0.955, green: 0.970, blue: 0.990, alpha: 0.875).setFill()
NSBezierPath(rect: canvasRect).fill()

let coolWash = NSGradient(colors: [
    NSColor(calibratedRed: 0.27, green: 0.71, blue: 0.96, alpha: 0.13),
    NSColor(calibratedRed: 0.55, green: 0.51, blue: 0.98, alpha: 0.075),
    NSColor.clear
])!
coolWash.draw(
    fromCenter: NSPoint(x: 640, y: 338),
    radius: 0,
    toCenter: NSPoint(x: 640, y: 338),
    radius: 690,
    options: [.drawsAfterEndingLocation]
)

func drawGlassCard(_ rect: NSRect, accent: NSColor) {
    let path = NSBezierPath(roundedRect: rect, xRadius: 28, yRadius: 28)
    NSColor.white.withAlphaComponent(0.34).setFill()
    path.fill()
    accent.withAlphaComponent(0.19).setStroke()
    path.lineWidth = 1
    path.stroke()
}

// The two panels frame the native Finder icons without replacing them. Their
// positions match the layout written by package_dmg.sh below.
drawGlassCard(NSRect(x: 126, y: 168, width: 388, height: 300), accent: .white)
drawGlassCard(
    NSRect(x: 766, y: 168, width: 388, height: 300),
    accent: NSColor(calibratedRed: 0.25, green: 0.66, blue: 0.94, alpha: 1)
)

func drawText(
    _ text: String,
    in rect: NSRect,
    font: NSFont,
    color: NSColor,
    alignment: NSTextAlignment = .left
) {
    let style = NSMutableParagraphStyle()
    style.alignment = alignment
    NSAttributedString(
        string: text,
        attributes: [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: style
        ]
    ).draw(in: rect)
}

// The title stays separate from Finder's icon labels so the installation step
// remains clear in any Finder language.
drawText(
    "ShotTessera for Mac",
    in: NSRect(x: 104, y: 632, width: 1072, height: 24),
    font: NSFont.systemFont(ofSize: 16, weight: .medium),
    color: NSColor(calibratedRed: 0.20, green: 0.30, blue: 0.42, alpha: 0.70),
    alignment: .center
)
drawText(
    "把影片织成一张分镜图",
    in: NSRect(x: 104, y: 581, width: 1072, height: 42),
    font: NSFont.systemFont(ofSize: 30, weight: .bold),
    color: NSColor(calibratedRed: 0.10, green: 0.16, blue: 0.25, alpha: 0.94),
    alignment: .center
)

drawText(
    "将左侧应用拖入右侧“应用程序”即可安装",
    in: NSRect(x: 104, y: 118, width: 1072, height: 24),
    font: NSFont.systemFont(ofSize: 15, weight: .medium),
    color: NSColor(calibratedRed: 0.18, green: 0.29, blue: 0.40, alpha: 0.70),
    alignment: .center
)
drawText(
    "支持 Apple Silicon 与 Intel Mac · macOS 13 及以上版本",
    in: NSRect(x: 104, y: 75, width: 1072, height: 20),
    font: NSFont.systemFont(ofSize: 12, weight: .regular),
    color: NSColor(calibratedRed: 0.25, green: 0.33, blue: 0.43, alpha: 0.50),
    alignment: .center
)

let arrowPath = NSBezierPath()
arrowPath.move(to: NSPoint(x: 588, y: 322))
arrowPath.line(to: NSPoint(x: 642, y: 322))
arrowPath.line(to: NSPoint(x: 626, y: 338))
arrowPath.move(to: NSPoint(x: 642, y: 322))
arrowPath.line(to: NSPoint(x: 626, y: 306))
arrowPath.lineWidth = 8
arrowPath.lineCapStyle = .round
arrowPath.lineJoinStyle = .round
NSColor(calibratedRed: 0.22, green: 0.58, blue: 0.86, alpha: 0.88).setStroke()
arrowPath.stroke()

NSGraphicsContext.restoreGraphicsState()
guard let pngData = bitmap.representation(using: .png, properties: [:]) else {
    throw InstallerBackgroundError.unableToWrite(outputURL.path)
}
try pngData.write(to: outputURL, options: .atomic)
