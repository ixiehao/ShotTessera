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
NSColor(calibratedRed: 0.025, green: 0.055, blue: 0.13, alpha: 0.84).setFill()
NSBezierPath(rect: canvasRect).fill()

let glow = NSGradient(colors: [
    NSColor(calibratedRed: 0.22, green: 0.78, blue: 0.96, alpha: 0.20),
    NSColor(calibratedRed: 0.56, green: 0.42, blue: 0.98, alpha: 0.10),
    NSColor.clear
])!
glow.draw(
    fromCenter: NSPoint(x: 640, y: 355),
    radius: 0,
    toCenter: NSPoint(x: 640, y: 355),
    radius: 465,
    options: [.drawsAfterEndingLocation]
)

func roundedPanel(_ rect: NSRect, radius: CGFloat, fill: NSColor, border: NSColor) {
    let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
    fill.setFill()
    path.fill()
    border.setStroke()
    path.lineWidth = 1
    path.stroke()
}

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

// A restrained, single installation rail gives the two draggable Finder icons
// a clear relationship without competing with them for attention.
roundedPanel(
    NSRect(x: 104, y: 168, width: 1072, height: 330),
    radius: 34,
    fill: NSColor.white.withAlphaComponent(0.065),
    border: NSColor.white.withAlphaComponent(0.16)
)
roundedPanel(
    NSRect(x: 142, y: 240, width: 208, height: 190),
    radius: 25,
    fill: NSColor.white.withAlphaComponent(0.105),
    border: NSColor.white.withAlphaComponent(0.20)
)
roundedPanel(
    NSRect(x: 930, y: 240, width: 208, height: 190),
    radius: 25,
    fill: NSColor.white.withAlphaComponent(0.105),
    border: NSColor.white.withAlphaComponent(0.20)
)
roundedPanel(
    NSRect(x: 488, y: 314, width: 304, height: 68),
    radius: 34,
    fill: NSColor(calibratedRed: 0.20, green: 0.77, blue: 0.95, alpha: 0.15),
    border: NSColor(calibratedRed: 0.41, green: 0.88, blue: 0.98, alpha: 0.42)
)
roundedPanel(
    NSRect(x: 136, y: 198, width: 220, height: 38),
    radius: 14,
    fill: NSColor.white.withAlphaComponent(0.66),
    border: NSColor.white.withAlphaComponent(0.25)
)
roundedPanel(
    NSRect(x: 924, y: 198, width: 220, height: 38),
    radius: 14,
    fill: NSColor.white.withAlphaComponent(0.66),
    border: NSColor.white.withAlphaComponent(0.25)
)

drawText(
    "INSTALL · 视频一键截屏拼图",
    in: NSRect(x: 104, y: 661, width: 760, height: 18),
    font: NSFont.systemFont(ofSize: 11, weight: .semibold),
    color: NSColor(calibratedRed: 0.46, green: 0.86, blue: 0.98, alpha: 1)
)
drawText(
    "把视频织成一张分镜图",
    in: NSRect(x: 104, y: 610, width: 820, height: 42),
    font: NSFont.systemFont(ofSize: 32, weight: .bold),
    color: .white
)
drawText(
    "将左侧 App 拖入右侧“应用程序”文件夹，即可完成安装。",
    in: NSRect(x: 104, y: 578, width: 880, height: 25),
    font: NSFont.systemFont(ofSize: 16, weight: .medium),
    color: NSColor.white.withAlphaComponent(0.74)
)
drawText(
    "01  应用",
    in: NSRect(x: 166, y: 394, width: 160, height: 18),
    font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .semibold),
    color: NSColor.white.withAlphaComponent(0.62),
    alignment: .center
)
drawText(
    "02  应用程序",
    in: NSRect(x: 950, y: 394, width: 168, height: 18),
    font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .semibold),
    color: NSColor.white.withAlphaComponent(0.62),
    alignment: .center
)
drawText(
    "拖入安装",
    in: NSRect(x: 520, y: 276, width: 240, height: 18),
    font: NSFont.systemFont(ofSize: 12, weight: .semibold),
    color: NSColor.white.withAlphaComponent(0.72),
    alignment: .center
)
drawText(
    "安装后，可从“应用程序”或 Launchpad 打开。",
    in: NSRect(x: 104, y: 98, width: 1072, height: 20),
    font: NSFont.systemFont(ofSize: 13, weight: .medium),
    color: NSColor.white.withAlphaComponent(0.62),
    alignment: .center
)

let arrowPath = NSBezierPath()
arrowPath.move(to: NSPoint(x: 540, y: 348))
arrowPath.line(to: NSPoint(x: 742, y: 348))
arrowPath.lineWidth = 7
arrowPath.lineCapStyle = .round
NSColor(calibratedRed: 0.34, green: 0.87, blue: 0.93, alpha: 0.95).setStroke()
arrowPath.stroke()

let arrowHead = NSBezierPath()
arrowHead.move(to: NSPoint(x: 742, y: 348))
arrowHead.line(to: NSPoint(x: 714, y: 370))
arrowHead.move(to: NSPoint(x: 742, y: 348))
arrowHead.line(to: NSPoint(x: 714, y: 326))
arrowHead.lineWidth = 7
arrowHead.lineCapStyle = .round
arrowHead.lineJoinStyle = .round
arrowHead.stroke()

NSGraphicsContext.restoreGraphicsState()
guard let pngData = bitmap.representation(using: .png, properties: [:]) else {
    throw InstallerBackgroundError.unableToWrite(outputURL.path)
}
try pngData.write(to: outputURL, options: .atomic)
