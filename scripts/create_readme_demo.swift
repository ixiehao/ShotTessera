import AppKit
import Foundation

/// Renders the README animation from primitives only. It intentionally uses no
/// downloaded footage, photographs, logos, or third-party artwork.

private let canvas = NSSize(width: 1200, height: 675)
private let frameCount = 12

private func color(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(calibratedRed: red, green: green, blue: blue, alpha: alpha)
}

private func roundedPath(_ rect: NSRect, radius: CGFloat) -> NSBezierPath {
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
}

private func fill(_ rect: NSRect, color fillColor: NSColor, radius: CGFloat = 0) {
    let path = radius > 0 ? roundedPath(rect, radius: radius) : NSBezierPath(rect: rect)
    fillColor.setFill()
    path.fill()
}

private func stroke(_ rect: NSRect, color strokeColor: NSColor, width: CGFloat = 1, radius: CGFloat = 0) {
    let path = radius > 0 ? roundedPath(rect, radius: radius) : NSBezierPath(rect: rect)
    strokeColor.setStroke()
    path.lineWidth = width
    path.stroke()
}

private func text(
    _ value: String,
    in rect: NSRect,
    size: CGFloat,
    weight: NSFont.Weight,
    color textColor: NSColor,
    alignment: NSTextAlignment = .left
) {
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = alignment
    paragraph.lineBreakMode = .byTruncatingTail
    let attributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: size, weight: weight),
        .foregroundColor: textColor,
        .paragraphStyle: paragraph
    ]
    (value as NSString).draw(in: rect, withAttributes: attributes)
}

private func drawPlayIcon(center: NSPoint, scale: CGFloat, tint: NSColor) {
    let path = NSBezierPath()
    path.move(to: NSPoint(x: center.x - scale * 0.34, y: center.y - scale * 0.48))
    path.line(to: NSPoint(x: center.x - scale * 0.34, y: center.y + scale * 0.48))
    path.line(to: NSPoint(x: center.x + scale * 0.52, y: center.y))
    path.close()
    tint.setFill()
    path.fill()
}

private func drawArrow(from start: NSPoint, to end: NSPoint, progress: CGFloat) {
    let visibleEnd = NSPoint(
        x: start.x + (end.x - start.x) * progress,
        y: start.y + (end.y - start.y) * progress
    )
    let path = NSBezierPath()
    path.move(to: start)
    path.line(to: visibleEnd)
    path.lineWidth = 6
    path.lineCapStyle = .round
    color(0.39, 0.87, 0.91, 0.25 + progress * 0.75).setStroke()
    path.stroke()

    guard progress > 0.72 else { return }
    let head = NSBezierPath()
    head.move(to: visibleEnd)
    head.line(to: NSPoint(x: visibleEnd.x - 20, y: visibleEnd.y + 15))
    head.move(to: visibleEnd)
    head.line(to: NSPoint(x: visibleEnd.x - 20, y: visibleEnd.y - 15))
    head.lineWidth = 6
    head.lineCapStyle = .round
    head.lineJoinStyle = .round
    color(0.39, 0.87, 0.91, 0.25 + progress * 0.75).setStroke()
    head.stroke()
}

private func drawSyntheticScene(in rect: NSRect, variant: Int, opacity: CGFloat = 1) {
    NSGraphicsContext.saveGraphicsState()
    roundedPath(rect, radius: 14).addClip()

    let tint = CGFloat(variant % 5) * 0.035
    let sky = NSGradient(colors: [
        color(0.035 + tint, 0.09 + tint, 0.20 + tint, opacity),
        color(0.13 + tint, 0.10 + tint, 0.30 + tint, opacity)
    ])!
    sky.draw(in: rect, angle: -35)

    let sunX = rect.minX + rect.width * (0.25 + CGFloat((variant * 17) % 47) / 100)
    let sunY = rect.minY + rect.height * (0.68 + CGFloat(variant % 3) * 0.035)
    fill(NSRect(x: sunX - rect.height * 0.09, y: sunY - rect.height * 0.09, width: rect.height * 0.18, height: rect.height * 0.18), color: color(1, 0.60, 0.30, opacity), radius: rect.height * 0.09)

    let farHill = NSBezierPath()
    farHill.move(to: NSPoint(x: rect.minX, y: rect.minY + rect.height * 0.38))
    farHill.curve(
        to: NSPoint(x: rect.maxX, y: rect.minY + rect.height * 0.36),
        controlPoint1: NSPoint(x: rect.minX + rect.width * 0.28, y: rect.minY + rect.height * (0.62 + tint)),
        controlPoint2: NSPoint(x: rect.minX + rect.width * 0.70, y: rect.minY + rect.height * (0.18 - tint))
    )
    farHill.line(to: NSPoint(x: rect.maxX, y: rect.minY))
    farHill.line(to: NSPoint(x: rect.minX, y: rect.minY))
    farHill.close()
    color(0.09, 0.24 + tint, 0.46 + tint, opacity).setFill()
    farHill.fill()

    let nearHill = NSBezierPath()
    nearHill.move(to: NSPoint(x: rect.minX, y: rect.minY + rect.height * 0.19))
    nearHill.curve(
        to: NSPoint(x: rect.maxX, y: rect.minY + rect.height * 0.24),
        controlPoint1: NSPoint(x: rect.minX + rect.width * 0.26, y: rect.minY + rect.height * (0.04 + tint)),
        controlPoint2: NSPoint(x: rect.minX + rect.width * 0.69, y: rect.minY + rect.height * (0.49 - tint))
    )
    nearHill.line(to: NSPoint(x: rect.maxX, y: rect.minY))
    nearHill.line(to: NSPoint(x: rect.minX, y: rect.minY))
    nearHill.close()
    color(0.025, 0.08 + tint, 0.18 + tint, opacity).setFill()
    nearHill.fill()

    let ribbon = NSBezierPath()
    ribbon.move(to: NSPoint(x: rect.minX - 8, y: rect.minY + rect.height * (0.18 + tint)))
    ribbon.curve(
        to: NSPoint(x: rect.maxX + 8, y: rect.minY + rect.height * (0.76 - tint)),
        controlPoint1: NSPoint(x: rect.minX + rect.width * 0.34, y: rect.minY + rect.height * 0.86),
        controlPoint2: NSPoint(x: rect.minX + rect.width * 0.66, y: rect.minY + rect.height * 0.04)
    )
    ribbon.lineWidth = max(2, rect.height * 0.022)
    ribbon.lineCapStyle = .round
    color(0.36, 0.89, 0.96, opacity * 0.88).setStroke()
    ribbon.stroke()

    for star in 0..<8 {
        let x = rect.minX + rect.width * CGFloat((star * 29 + variant * 11) % 93 + 4) / 100
        let y = rect.minY + rect.height * CGFloat((star * 17 + variant * 7) % 52 + 40) / 100
        fill(NSRect(x: x, y: y, width: 2.2, height: 2.2), color: color(0.74, 0.95, 1, opacity * 0.8), radius: 1.1)
    }

    NSGraphicsContext.restoreGraphicsState()
}

private func drawFilmStrip(in rect: NSRect, phase: CGFloat) {
    fill(rect, color: color(0.02, 0.04, 0.09, 0.86), radius: 22)
    stroke(rect, color: color(0.50, 0.88, 0.96, 0.20), width: 1, radius: 22)
    text("SOURCE VIDEO", in: NSRect(x: rect.minX + 24, y: rect.maxY - 42, width: rect.width - 48, height: 18), size: 12, weight: .bold, color: color(0.65, 0.82, 0.95))

    let screen = NSRect(x: rect.minX + 22, y: rect.minY + 42, width: rect.width - 44, height: rect.height - 92)
    drawSyntheticScene(in: screen, variant: Int(phase * 8), opacity: 1)
    stroke(screen, color: color(1, 1, 1, 0.18), width: 1, radius: 14)
    fill(NSRect(x: screen.minX + 13, y: screen.minY + 13, width: 64, height: 22), color: color(0.02, 0.04, 0.08, 0.70), radius: 11)
    let timestamp = String(format: "00:%02d", Int(phase * 8) + 1)
    text(timestamp, in: NSRect(x: screen.minX + 17, y: screen.minY + 17, width: 56, height: 11), size: 8, weight: .semibold, color: .white)

    let playCircle = NSRect(x: screen.midX - 28, y: screen.midY - 28, width: 56, height: 56)
    fill(playCircle, color: color(0.06, 0.12, 0.22, 0.52), radius: 28)
    stroke(playCircle, color: color(0.84, 0.97, 1, 0.56), width: 1, radius: 28)
    drawPlayIcon(center: NSPoint(x: playCircle.midX + 2, y: playCircle.midY), scale: 16, tint: .white)

    fill(NSRect(x: screen.minX, y: screen.minY - 16, width: screen.width, height: 4), color: color(1, 1, 1, 0.15), radius: 2)
    fill(NSRect(x: screen.minX, y: screen.minY - 16, width: screen.width * max(0.12, phase), height: 4), color: color(0.38, 0.87, 0.91), radius: 2)
}

private func drawStoryboard(in rect: NSRect, phase: CGFloat) {
    fill(rect, color: color(0.02, 0.04, 0.09, 0.86), radius: 22)
    stroke(rect, color: color(0.55, 0.70, 1, 0.22), width: 1, radius: 22)
    text("3 × 3 STORYBOARD", in: NSRect(x: rect.minX + 24, y: rect.maxY - 42, width: rect.width - 48, height: 18), size: 12, weight: .bold, color: color(0.70, 0.81, 1.0))

    let inset: CGFloat = 22
    let spacing: CGFloat = 8
    let content = NSRect(x: rect.minX + inset, y: rect.minY + 22, width: rect.width - inset * 2, height: rect.height - 74)
    let cardWidth = (content.width - spacing * 2) / 3
    let cardHeight = (content.height - spacing * 2) / 3
    let completed = phase * 11

    for row in 0..<3 {
        for column in 0..<3 {
            let index = row * 3 + column
            let x = content.minX + CGFloat(column) * (cardWidth + spacing)
            let y = content.maxY - CGFloat(row + 1) * cardHeight - CGFloat(row) * spacing
            let card = NSRect(x: x, y: y, width: cardWidth, height: cardHeight)
            let tileProgress = max(0, min(1, completed - CGFloat(index)))
            fill(card, color: color(0.10, 0.14, 0.24, 1), radius: 9)
            if tileProgress > 0 {
                drawSyntheticScene(in: card, variant: index + Int(phase * 7), opacity: tileProgress)
                fill(card, color: color(0.04, 0.08, 0.14, (1 - tileProgress) * 0.7), radius: 9)
            }
            stroke(card, color: color(0.75, 0.92, 1, tileProgress > 0 ? 0.30 : 0.10), width: 0.8, radius: 9)
        }
    }
}

private func drawFrame(index: Int) -> Data {
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
    context.imageInterpolation = NSImageInterpolation.high

    let phase = CGFloat(index) / CGFloat(frameCount - 1)
    let background = NSGradient(colors: [color(0.025, 0.035, 0.085), color(0.10, 0.065, 0.18)])!
    background.draw(in: NSRect(origin: .zero, size: canvas), angle: -35)

    let glow = NSRect(x: 340, y: 80, width: 520, height: 520)
    fill(glow, color: color(0.18, 0.45, 0.70, 0.055), radius: 260)

    text("SHOT TESSERA", in: NSRect(x: 0, y: 604, width: canvas.width, height: 22), size: 13, weight: .bold, color: color(0.46, 0.87, 0.91), alignment: .center)
    text("VIDEO  →  NINE-FRAME STORYBOARD", in: NSRect(x: 0, y: 552, width: canvas.width, height: 38), size: 30, weight: .bold, color: color(0.90, 0.96, 1.0), alignment: .center)
    text("Smart selection · Local export", in: NSRect(x: 0, y: 524, width: canvas.width, height: 18), size: 13, weight: .medium, color: color(0.60, 0.75, 0.92), alignment: .center)

    let left = NSRect(x: 78, y: 160, width: 430, height: 302)
    let right = NSRect(x: 692, y: 160, width: 430, height: 302)
    drawFilmStrip(in: left, phase: phase)
    drawStoryboard(in: right, phase: phase)
    drawArrow(from: NSPoint(x: left.maxX + 52, y: 305), to: NSPoint(x: right.minX - 52, y: 305), progress: min(1, phase * 1.4))

    for item in 0..<3 {
        let itemPhase = max(0, min(1, phase * 3.2 - CGFloat(item)))
        let dot = NSRect(x: 472 + CGFloat(item) * 82, y: 290 + sin(phase * .pi) * 18, width: 20, height: 20)
        fill(dot, color: color(0.43, 0.86, 0.93, itemPhase), radius: 10)
    }

    NSGraphicsContext.restoreGraphicsState()
    return bitmap.representation(using: .png, properties: [:])!
}

guard CommandLine.arguments.count == 2 else {
    fputs("Usage: create_readme_demo.swift <output-directory>\n", stderr)
    exit(64)
}

let outputDirectory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
for index in 0..<frameCount {
    let output = outputDirectory.appendingPathComponent(String(format: "frame-%02d.png", index))
    try drawFrame(index: index).write(to: output)
}
