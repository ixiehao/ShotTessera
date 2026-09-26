import AppKit
import Foundation

enum GuideBackgroundError: Error {
    case invalidArguments
    case unableToCreateBitmap
    case unableToWrite
}

guard CommandLine.arguments.count == 2 else {
    throw GuideBackgroundError.invalidArguments
}

let outputURL = URL(fileURLWithPath: CommandLine.arguments[1])
let size = NSSize(width: 1600, height: 1000)
guard let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: Int(size.width),
    pixelsHigh: Int(size.height),
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
), let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
    throw GuideBackgroundError.unableToCreateBitmap
}

func color(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(calibratedRed: red, green: green, blue: blue, alpha: alpha)
}

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = context
let rect = NSRect(origin: .zero, size: size)
NSGradient(colors: [color(0.020, 0.041, 0.095), color(0.058, 0.050, 0.150)])!
    .draw(in: rect, angle: -24)

let aquaGlow = NSGradient(colors: [color(0.20, 0.78, 0.92, 0.20), .clear])!
aquaGlow.draw(
    fromCenter: NSPoint(x: 1180, y: 770), radius: 0,
    toCenter: NSPoint(x: 1180, y: 770), radius: 700,
    options: [.drawsAfterEndingLocation]
)
let violetGlow = NSGradient(colors: [color(0.43, 0.36, 0.96, 0.15), .clear])!
violetGlow.draw(
    fromCenter: NSPoint(x: 260, y: 170), radius: 0,
    toCenter: NSPoint(x: 260, y: 170), radius: 610,
    options: [.drawsAfterEndingLocation]
)

for offset in stride(from: -340 as CGFloat, through: 1480, by: 230) {
    let path = NSBezierPath()
    path.move(to: NSPoint(x: offset, y: -40))
    path.curve(
        to: NSPoint(x: offset + 470, y: 1040),
        controlPoint1: NSPoint(x: offset + 190, y: 260),
        controlPoint2: NSPoint(x: offset + 280, y: 760)
    )
    path.lineWidth = 1
    color(0.52, 0.86, 1.0, 0.065).setStroke()
    path.stroke()
}

NSGraphicsContext.restoreGraphicsState()
guard let png = bitmap.representation(using: .png, properties: [:]) else {
    throw GuideBackgroundError.unableToWrite
}
try png.write(to: outputURL, options: .atomic)
