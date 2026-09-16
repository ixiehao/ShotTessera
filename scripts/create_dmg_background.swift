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
    .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: 32])
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
NSColor(calibratedRed: 0.965, green: 0.970, blue: 0.980, alpha: 0.960).setFill()
NSBezierPath(rect: canvasRect).fill()

let coolWash = NSGradient(colors: [
    NSColor(calibratedRed: 0.34, green: 0.80, blue: 0.98, alpha: 0.048),
    NSColor(calibratedRed: 0.56, green: 0.53, blue: 0.98, alpha: 0.022),
    NSColor.clear
])!
coolWash.draw(
    fromCenter: NSPoint(x: 640, y: 300),
    radius: 0,
    toCenter: NSPoint(x: 640, y: 300),
    radius: 610,
    options: [.drawsAfterEndingLocation]
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

// Keep the header independent from Finder's icon labels: it identifies the
// product while the two native icons below retain the entire installation flow.
drawText(
    "视频一键截屏拼图",
    in: NSRect(x: 104, y: 610, width: 1072, height: 42),
    font: NSFont.systemFont(ofSize: 31, weight: .bold),
    color: NSColor(calibratedRed: 0.14, green: 0.17, blue: 0.23, alpha: 0.96),
    alignment: .center
)
drawText(
    "拖入“应用程序”完成安装",
    in: NSRect(x: 104, y: 573, width: 1072, height: 24),
    font: NSFont.systemFont(ofSize: 16, weight: .medium),
    color: NSColor(calibratedRed: 0.31, green: 0.34, blue: 0.40, alpha: 0.64),
    alignment: .center
)

drawText(
    "适用于 Apple Silicon 与 Intel Mac · macOS 13 及以上版本",
    in: NSRect(x: 104, y: 80, width: 1072, height: 20),
    font: NSFont.systemFont(ofSize: 13, weight: .regular),
    color: NSColor(calibratedRed: 0.31, green: 0.34, blue: 0.40, alpha: 0.48),
    alignment: .center
)

let arrowPath = NSBezierPath()
arrowPath.move(to: NSPoint(x: 607, y: 340))
arrowPath.line(to: NSPoint(x: 655, y: 300))
arrowPath.line(to: NSPoint(x: 607, y: 260))
arrowPath.lineWidth = 10
arrowPath.lineCapStyle = .round
arrowPath.lineJoinStyle = .round
NSColor(calibratedRed: 0.18, green: 0.21, blue: 0.27, alpha: 0.75).setStroke()
arrowPath.stroke()

NSGraphicsContext.restoreGraphicsState()
guard let pngData = bitmap.representation(using: .png, properties: [:]) else {
    throw InstallerBackgroundError.unableToWrite(outputURL.path)
}
try pngData.write(to: outputURL, options: .atomic)
