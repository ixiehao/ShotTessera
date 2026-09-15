import AppKit
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

enum StoryboardComposer {
    static func render(result: StoryboardResult, settings: ExportSettings) throws -> Data {
        let width = settings.safeWidth
        let side = settings.gridSide
        let margin = max(28, width / 42)
        let gap = max(10, width / 190)
        let cellWidth = (width - margin * 2 - gap * (side - 1)) / side
        let cellHeight = Int(Double(cellWidth) * 9.0 / 16.0)
        let height = margin * 2 + cellHeight * side + gap * (side - 1)

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { throw StoryboardError.noExportData }

        context.setFillColor(CGColor(red: 0.055, green: 0.063, blue: 0.086, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))

        for cellIndex in 0..<(side * side) {
            let column = cellIndex % side
            let row = side - 1 - cellIndex / side
            let x = margin + column * (cellWidth + gap)
            let y = margin + row * (cellHeight + gap)
            let rect = CGRect(x: x, y: y, width: cellWidth, height: cellHeight)
            let frame = result.frames[safe: cellIndex] ?? result.frames.last
            drawCard(in: context, rect: rect, imageData: frame?.jpegData)
        }

        guard let image = context.makeImage() else { throw StoryboardError.noExportData }
        let mutableData = NSMutableData()
        let type: CFString = settings.format == .png ? UTType.png.identifier as CFString : UTType.jpeg.identifier as CFString
        guard let destination = CGImageDestinationCreateWithData(mutableData, type, 1, nil) else {
            throw StoryboardError.noExportData
        }
        let options: [CFString: Any] = settings.format == .jpeg ? [kCGImageDestinationLossyCompressionQuality: 0.94] : [:]
        CGImageDestinationAddImage(destination, image, options as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw StoryboardError.noExportData }
        return mutableData as Data
    }

    private static func drawCard(in context: CGContext, rect: CGRect, imageData: Data?) {
        let radius = min(rect.width, rect.height) * 0.055
        let cardPath = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
        context.setFillColor(CGColor(red: 0.15, green: 0.17, blue: 0.22, alpha: 1))
        context.addPath(cardPath)
        context.fillPath()

        guard let imageData, let image = NSImage(data: imageData)?.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return }
        context.saveGState()
        context.addPath(cardPath)
        context.clip()
        drawAspectFill(image, in: rect, context: context)
        context.restoreGState()

        context.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.08))
        context.setLineWidth(max(1, rect.width * 0.003))
        context.addPath(cardPath)
        context.strokePath()
    }

    private static func drawAspectFill(_ image: CGImage, in rect: CGRect, context: CGContext) {
        let sourceRatio = CGFloat(image.width) / CGFloat(image.height)
        let targetRatio = rect.width / rect.height
        let drawRect: CGRect
        if sourceRatio > targetRatio {
            let width = rect.height * sourceRatio
            drawRect = CGRect(x: rect.midX - width / 2, y: rect.minY, width: width, height: rect.height)
        } else {
            let height = rect.width / sourceRatio
            drawRect = CGRect(x: rect.minX, y: rect.midY - height / 2, width: rect.width, height: height)
        }
        context.interpolationQuality = .high
        context.draw(image, in: drawRect)
    }
}

private extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
