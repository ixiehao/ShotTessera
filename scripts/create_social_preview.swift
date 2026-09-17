import AppKit
import Foundation

/// Adds deterministic, legible product copy to the repository social card.
/// The source visual remains untouched; this script writes a new sibling file.

private let canvas = NSSize(width: 1280, height: 640)

private func color(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(calibratedRed: red, green: green, blue: blue, alpha: alpha)
}

private func rounded(_ rect: NSRect, radius: CGFloat) -> NSBezierPath {
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
}

private func drawText(
    _ value: String,
    in rect: NSRect,
    size: CGFloat,
    weight: NSFont.Weight,
    color textColor: NSColor,
    tracking: CGFloat = 0
) {
    let style = NSMutableParagraphStyle()
    style.lineBreakMode = .byTruncatingTail
    let attributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: size, weight: weight),
        .foregroundColor: textColor,
        .kern: tracking,
        .paragraphStyle: style
    ]
    (value as NSString).draw(in: rect, withAttributes: attributes)
}

guard CommandLine.arguments.count == 3 else {
    fputs("Usage: create_social_preview.swift <input.jpg> <output.jpg>\n", stderr)
    exit(64)
}

let inputURL = URL(fileURLWithPath: CommandLine.arguments[1])
let outputURL = URL(fileURLWithPath: CommandLine.arguments[2])
guard let source = NSImage(contentsOf: inputURL) else {
    fputs("Cannot load input image: \(inputURL.path)\n", stderr)
    exit(1)
}

let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: Int(canvas.width),
    pixelsHigh: Int(canvas.height),
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
)!
let context = NSGraphicsContext(bitmapImageRep: bitmap)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = context
context.imageInterpolation = .high

source.draw(in: NSRect(origin: .zero, size: canvas), from: .zero, operation: .sourceOver, fraction: 1)

let panel = NSRect(x: 54, y: 442, width: 648, height: 144)
color(0.012, 0.03, 0.09, 0.72).setFill()
rounded(panel, radius: 20).fill()
color(0.42, 0.86, 1, 0.34).setStroke()
let panelStroke = rounded(panel, radius: 20)
panelStroke.lineWidth = 1
panelStroke.stroke()

let pill = NSRect(x: 78, y: 548, width: 86, height: 24)
color(0.16, 0.76, 0.91, 0.22).setFill()
rounded(pill, radius: 12).fill()
drawText("v0.2.3", in: NSRect(x: 92, y: 553, width: 60, height: 16), size: 11, weight: .bold, color: color(0.55, 0.94, 1), tracking: 0.4)

drawText("ShotTessera", in: NSRect(x: 78, y: 500, width: 420, height: 40), size: 34, weight: .bold, color: color(0.95, 0.985, 1))
drawText("Turn video into storyboards on macOS", in: NSRect(x: 80, y: 474, width: 560, height: 24), size: 18, weight: .semibold, color: color(0.68, 0.88, 1))
drawText("Smart selection · Fine-tune frames · Fully local", in: NSRect(x: 80, y: 453, width: 560, height: 18), size: 13, weight: .medium, color: color(0.53, 0.76, 0.94), tracking: 0.1)

NSGraphicsContext.restoreGraphicsState()
guard let data = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.83]) else {
    fputs("Cannot encode JPEG\n", stderr)
    exit(1)
}
try data.write(to: outputURL)
