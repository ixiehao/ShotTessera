import SwiftUI

/// Original interface pictograms for ShotTessera. They are drawn from simple
/// geometry in this source file and are released with the project under MIT.
/// No third-party icon font, glyph library, or trademarked artwork is bundled.
struct ProjectIcon: View {
    enum Symbol {
        case language, disclosure, check, selector, grid, layers, export
        case wand, previous, next, folder, save, sliders, film, selected
        case eye, filmStack, plus, trash, refresh
    }

    let symbol: Symbol
    var size: CGFloat = 16

    var body: some View {
        ProjectIconPath(symbol: symbol)
            .stroke(style: StrokeStyle(lineWidth: max(1.35, size * 0.105), lineCap: .round, lineJoin: .round))
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

struct GlyphLabel: View {
    let title: String
    let glyph: ProjectIcon.Symbol
    var glyphSize: CGFloat = 15

    var body: some View {
        Label {
            Text(title)
        } icon: {
            ProjectIcon(symbol: glyph, size: glyphSize)
        }
    }
}

private struct ProjectIconPath: Shape {
    let symbol: ProjectIcon.Symbol

    func path(in rect: CGRect) -> Path {
        let side = min(rect.width, rect.height)
        let offsetX = rect.midX - side / 2
        let offsetY = rect.midY - side / 2
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: offsetX + x * side / 24, y: offsetY + y * side / 24)
        }
        func area(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat) -> CGRect {
            CGRect(
                x: offsetX + x * side / 24,
                y: offsetY + y * side / 24,
                width: width * side / 24,
                height: height * side / 24
            )
        }

        var path = Path()
        switch symbol {
        case .language:
            path.addEllipse(in: area(3, 3, 18, 18))
            path.move(to: point(3.5, 12)); path.addLine(to: point(20.5, 12))
            path.move(to: point(12, 3.3)); path.addCurve(to: point(12, 20.7), control1: point(7.5, 7), control2: point(7.5, 17))
            path.move(to: point(12, 3.3)); path.addCurve(to: point(12, 20.7), control1: point(16.5, 7), control2: point(16.5, 17))
        case .disclosure:
            path.move(to: point(7, 9)); path.addLine(to: point(12, 14)); path.addLine(to: point(17, 9))
        case .check:
            path.move(to: point(4.7, 12.6)); path.addLine(to: point(9.5, 17.1)); path.addLine(to: point(19.3, 6.8))
        case .selector:
            path.move(to: point(7.5, 10)); path.addLine(to: point(12, 5.5)); path.addLine(to: point(16.5, 10))
            path.move(to: point(7.5, 14)); path.addLine(to: point(12, 18.5)); path.addLine(to: point(16.5, 14))
        case .grid:
            for row in 0..<3 {
                for column in 0..<3 {
                    path.addRoundedRect(in: area(3 + CGFloat(column) * 6.2, 3 + CGFloat(row) * 6.2, 3.8, 3.8), cornerSize: CGSize(width: 0.8, height: 0.8))
                }
            }
        case .layers:
            path.addRoundedRect(in: area(3, 5, 13, 11), cornerSize: CGSize(width: 1.4, height: 1.4))
            path.addRoundedRect(in: area(8, 9, 13, 11), cornerSize: CGSize(width: 1.4, height: 1.4))
        case .export:
            path.move(to: point(12, 3)); path.addLine(to: point(12, 15.5))
            path.move(to: point(7.3, 11)); path.addLine(to: point(12, 15.8)); path.addLine(to: point(16.7, 11))
            path.move(to: point(4, 20)); path.addLine(to: point(20, 20))
        case .wand:
            path.move(to: point(7.2, 17)); path.addLine(to: point(16.8, 7.4))
            path.move(to: point(4, 7)); path.addLine(to: point(8, 7)); path.move(to: point(6, 5)); path.addLine(to: point(6, 9))
            path.move(to: point(16.5, 17.5)); path.addLine(to: point(21, 17.5)); path.move(to: point(18.8, 15.3)); path.addLine(to: point(18.8, 19.7))
        case .previous:
            path.move(to: point(15.5, 4)); path.addLine(to: point(7.5, 12)); path.addLine(to: point(15.5, 20))
        case .next:
            path.move(to: point(8.5, 4)); path.addLine(to: point(16.5, 12)); path.addLine(to: point(8.5, 20))
        case .folder:
            path.move(to: point(3, 8)); path.addLine(to: point(9.3, 8)); path.addLine(to: point(11.2, 5.5)); path.addLine(to: point(16, 5.5)); path.addLine(to: point(20.5, 8)); path.addLine(to: point(20.5, 19)); path.addLine(to: point(3, 19)); path.closeSubpath()
        case .save:
            path.addRoundedRect(in: area(4, 13.5, 16, 6.5), cornerSize: CGSize(width: 1.2, height: 1.2))
            path.move(to: point(12, 3)); path.addLine(to: point(12, 14.2))
            path.move(to: point(7.5, 9.7)); path.addLine(to: point(12, 14.2)); path.addLine(to: point(16.5, 9.7))
        case .sliders:
            path.move(to: point(4, 6)); path.addLine(to: point(20, 6)); path.addEllipse(in: area(8, 3.8, 4.4, 4.4))
            path.move(to: point(4, 12)); path.addLine(to: point(20, 12)); path.addEllipse(in: area(13.4, 9.8, 4.4, 4.4))
            path.move(to: point(4, 18)); path.addLine(to: point(20, 18)); path.addEllipse(in: area(6.1, 15.8, 4.4, 4.4))
        case .film:
            path.addRoundedRect(in: area(3, 4, 18, 16), cornerSize: CGSize(width: 2, height: 2))
            path.move(to: point(7.5, 4)); path.addLine(to: point(7.5, 20))
            path.move(to: point(16.5, 4)); path.addLine(to: point(16.5, 20))
            path.move(to: point(3, 9)); path.addLine(to: point(7.5, 9)); path.move(to: point(16.5, 9)); path.addLine(to: point(21, 9))
            path.move(to: point(3, 15)); path.addLine(to: point(7.5, 15)); path.move(to: point(16.5, 15)); path.addLine(to: point(21, 15))
        case .selected:
            path.addEllipse(in: area(3, 3, 18, 18))
            path.move(to: point(7, 12.5)); path.addLine(to: point(10.5, 16)); path.addLine(to: point(17.5, 8.5))
        case .eye:
            path.move(to: point(2.5, 12)); path.addCurve(to: point(21.5, 12), control1: point(7, 5.5), control2: point(17, 5.5))
            path.addCurve(to: point(2.5, 12), control1: point(17, 18.5), control2: point(7, 18.5))
            path.addEllipse(in: area(9, 9, 6, 6))
        case .filmStack:
            path.addRoundedRect(in: area(3, 7, 15, 12), cornerSize: CGSize(width: 1.8, height: 1.8))
            path.addRoundedRect(in: area(7, 4, 14, 12), cornerSize: CGSize(width: 1.8, height: 1.8))
            path.move(to: point(10.5, 4)); path.addLine(to: point(10.5, 16))
            path.move(to: point(17.5, 4)); path.addLine(to: point(17.5, 16))
        case .plus:
            path.move(to: point(12, 4)); path.addLine(to: point(12, 20))
            path.move(to: point(4, 12)); path.addLine(to: point(20, 12))
        case .trash:
            path.move(to: point(5, 7)); path.addLine(to: point(19, 7))
            path.move(to: point(9, 4)); path.addLine(to: point(15, 4))
            path.addRoundedRect(in: area(6.5, 7, 11, 13), cornerSize: CGSize(width: 1.4, height: 1.4))
            path.move(to: point(10, 10)); path.addLine(to: point(10, 17)); path.move(to: point(14, 10)); path.addLine(to: point(14, 17))
        case .refresh:
            path.addArc(center: point(12, 12), radius: side * 7.5 / 24, startAngle: .degrees(40), endAngle: .degrees(320), clockwise: false)
            path.move(to: point(17.4, 5.6)); path.addLine(to: point(19.6, 5.8)); path.addLine(to: point(19.2, 8))
        }
        return path
    }
}
