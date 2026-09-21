import SwiftUI

/// Original ShotTessera interface pictograms. Every symbol is constructed from
/// project-owned geometry on a 24-point grid and released under this project's
/// MIT license; no icon font, third-party library, or trademarked artwork is used.
struct ProjectIcon: View {
    enum Symbol {
        case language, appearance, moon, disclosure, check, selector
        case grid, frame, layers, export, privacy, videoImport
        case wand, smartSelect, refreshCandidates, previous, next, skipPrevious, skipNext, folder, folderCheck, save, sliders, frameSelect
        case film, selected, eye, filmStack, plus, trash, refresh, pause, play, ellipsis
    }

    let symbol: Symbol
    var size: CGFloat = 16

    var body: some View {
        Group {
            if symbol == .moon {
                ProjectIconPath(symbol: symbol)
                    .fill()
            } else {
                ProjectIconPath(symbol: symbol)
                    .stroke(
                        style: StrokeStyle(
                            lineWidth: max(1.35, size / 12),
                            lineCap: .round,
                            lineJoin: .round
                        )
                    )
            }
        }
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
        func corner(_ value: CGFloat) -> CGSize {
            CGSize(width: value * side / 24, height: value * side / 24)
        }
        func rounded(_ path: inout Path, _ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat, _ radius: CGFloat) {
            path.addRoundedRect(in: area(x, y, width, height), cornerSize: corner(radius))
        }

        var path = Path()
        switch symbol {
        case .language:
            path.addEllipse(in: area(3, 3, 18, 18))
            path.move(to: point(4.2, 12)); path.addLine(to: point(19.8, 12))
            path.move(to: point(12, 3.4)); path.addCurve(to: point(12, 20.6), control1: point(7.6, 7.2), control2: point(7.6, 16.8))
            path.move(to: point(12, 3.4)); path.addCurve(to: point(12, 20.6), control1: point(16.4, 7.2), control2: point(16.4, 16.8))

        case .appearance:
            path.addEllipse(in: area(8, 8, 8, 8))
            for index in 0..<8 {
                let angle = CGFloat(index) * .pi / 4
                let start = CGPoint(x: rect.midX + cos(angle) * side * 6.6 / 24, y: rect.midY + sin(angle) * side * 6.6 / 24)
                let end = CGPoint(x: rect.midX + cos(angle) * side * 9.1 / 24, y: rect.midY + sin(angle) * side * 9.1 / 24)
                path.move(to: start); path.addLine(to: end)
            }

        case .moon:
            path.move(to: point(18.9, 15.8))
            path.addCurve(to: point(10.1, 19.7), control1: point(16.7, 18.4), control2: point(12.4, 19.9))
            path.addCurve(to: point(5.4, 10.7), control1: point(6.4, 18.0), control2: point(4.4, 14.2))
            path.addCurve(to: point(11.6, 3.8), control1: point(6.1, 7.5), control2: point(8.5, 4.8))
            path.addCurve(to: point(18.9, 15.8), control1: point(9.9, 7.0), control2: point(13.1, 14.4))
            path.closeSubpath()

        case .disclosure:
            path.move(to: point(7.5, 9.5)); path.addLine(to: point(12, 14)); path.addLine(to: point(16.5, 9.5))

        case .check:
            path.move(to: point(4.8, 12.4)); path.addLine(to: point(9.4, 17)); path.addLine(to: point(19.2, 7.1))

        case .selector:
            path.move(to: point(7.8, 9.8)); path.addLine(to: point(12, 5.6)); path.addLine(to: point(16.2, 9.8))
            path.move(to: point(7.8, 14.2)); path.addLine(to: point(12, 18.4)); path.addLine(to: point(16.2, 14.2))

        case .ellipsis:
            path.addEllipse(in: area(3.3, 10.3, 3.4, 3.4))
            path.addEllipse(in: area(10.3, 10.3, 3.4, 3.4))
            path.addEllipse(in: area(17.3, 10.3, 3.4, 3.4))

        case .grid:
            rounded(&path, 4, 4, 6, 6, 1.3)
            rounded(&path, 14, 4, 6, 6, 1.3)
            rounded(&path, 4, 14, 6, 6, 1.3)
            rounded(&path, 14, 14, 6, 6, 1.3)

        case .frame:
            rounded(&path, 3, 5.5, 18, 13, 2)
            path.move(to: point(6.8, 15.2)); path.addLine(to: point(10.2, 11.8)); path.addLine(to: point(13, 14.6)); path.addLine(to: point(16.8, 10.8)); path.addLine(to: point(18.3, 12.3))

        case .layers:
            rounded(&path, 3.2, 4.5, 13.6, 11.4, 1.8)
            rounded(&path, 7.2, 8.4, 13.6, 11.4, 1.8)

        case .export:
            path.move(to: point(12, 3.2)); path.addLine(to: point(12, 14.3))
            path.move(to: point(7.7, 10.3)); path.addLine(to: point(12, 14.6)); path.addLine(to: point(16.3, 10.3))
            path.move(to: point(4.2, 15.2)); path.addLine(to: point(4.2, 19.1)); path.addLine(to: point(19.8, 19.1)); path.addLine(to: point(19.8, 15.2))

        case .privacy:
            path.move(to: point(12, 3.2)); path.addLine(to: point(19.1, 6.2)); path.addLine(to: point(19.1, 11.5))
            path.addCurve(to: point(12, 20.6), control1: point(18.8, 15.5), control2: point(15.2, 19.0))
            path.addCurve(to: point(4.9, 11.5), control1: point(8.8, 19.0), control2: point(5.2, 15.5))
            path.addLine(to: point(4.9, 6.2)); path.closeSubpath()
            path.move(to: point(8.6, 11.9)); path.addLine(to: point(10.8, 14.1)); path.addLine(to: point(15.4, 9.6))

        case .videoImport:
            rounded(&path, 3, 7.2, 18, 12.4, 2)
            path.move(to: point(7.6, 7.2)); path.addLine(to: point(7.6, 19.6))
            path.move(to: point(16.4, 7.2)); path.addLine(to: point(16.4, 19.6))
            path.move(to: point(12, 3.3)); path.addLine(to: point(12, 11.7))
            path.move(to: point(8.9, 8.7)); path.addLine(to: point(12, 11.8)); path.addLine(to: point(15.1, 8.7))

        case .wand:
            path.move(to: point(7.3, 17.2)); path.addLine(to: point(16.7, 7.8))
            path.move(to: point(16.9, 3.4)); path.addLine(to: point(16.9, 8.2)); path.move(to: point(14.5, 5.8)); path.addLine(to: point(19.3, 5.8))
            path.move(to: point(5.2, 11.2)); path.addLine(to: point(5.2, 14.4)); path.move(to: point(3.6, 12.8)); path.addLine(to: point(6.8, 12.8))

        case .smartSelect:
            // A candidate frame with a deliberate check mark and a small sparkle.
            // It reads as "choose the best frames", rather than a generic magic wand.
            rounded(&path, 3.5, 5.8, 12.8, 12.8, 2.1)
            path.move(to: point(7.8, 5.8)); path.addLine(to: point(7.8, 18.6))
            path.move(to: point(12.2, 5.8)); path.addLine(to: point(12.2, 18.6))
            path.move(to: point(3.5, 10.1)); path.addLine(to: point(16.3, 10.1))
            path.move(to: point(7.0, 14.2)); path.addLine(to: point(9.0, 16.1)); path.addLine(to: point(13.5, 11.9))
            path.move(to: point(19.2, 3.5)); path.addLine(to: point(19.2, 8.2))
            path.move(to: point(16.9, 5.85)); path.addLine(to: point(21.5, 5.85))

        case .refreshCandidates:
            // Two compact arcs suggest cycling through a fresh candidate set.
            path.addArc(center: point(12, 12), radius: side * 7.3 / 24, startAngle: .degrees(42), endAngle: .degrees(174), clockwise: false)
            path.addArc(center: point(12, 12), radius: side * 7.3 / 24, startAngle: .degrees(222), endAngle: .degrees(354), clockwise: false)
            path.move(to: point(17.0, 5.8)); path.addLine(to: point(20.0, 5.8)); path.addLine(to: point(19.3, 8.7))
            path.move(to: point(7.0, 18.2)); path.addLine(to: point(4.0, 18.2)); path.addLine(to: point(4.7, 15.3))
            path.addEllipse(in: area(10.5, 10.5, 3, 3))

        case .previous:
            path.move(to: point(14.5, 6)); path.addLine(to: point(8.5, 12)); path.addLine(to: point(14.5, 18))

        case .next:
            path.move(to: point(9.5, 6)); path.addLine(to: point(15.5, 12)); path.addLine(to: point(9.5, 18))

        case .skipPrevious:
            path.move(to: point(5.0, 5.4)); path.addLine(to: point(5.0, 18.6))
            path.move(to: point(18.8, 6)); path.addLine(to: point(12.8, 12)); path.addLine(to: point(18.8, 18))
            path.move(to: point(12.8, 6)); path.addLine(to: point(6.8, 12)); path.addLine(to: point(12.8, 18))

        case .skipNext:
            path.move(to: point(19.0, 5.4)); path.addLine(to: point(19.0, 18.6))
            path.move(to: point(5.2, 6)); path.addLine(to: point(11.2, 12)); path.addLine(to: point(5.2, 18))
            path.move(to: point(11.2, 6)); path.addLine(to: point(17.2, 12)); path.addLine(to: point(11.2, 18))

        case .folder:
            path.move(to: point(3.2, 7.8)); path.addLine(to: point(9.2, 7.8)); path.addLine(to: point(11.2, 5.3)); path.addLine(to: point(16.2, 5.3)); path.addLine(to: point(20.8, 8.1)); path.addLine(to: point(20.8, 19)); path.addLine(to: point(3.2, 19)); path.closeSubpath()

        case .folderCheck:
            path.move(to: point(3.2, 7.8)); path.addLine(to: point(9.2, 7.8)); path.addLine(to: point(11.2, 5.3)); path.addLine(to: point(16.2, 5.3)); path.addLine(to: point(20.8, 8.1)); path.addLine(to: point(20.8, 19)); path.addLine(to: point(3.2, 19)); path.closeSubpath()
            path.move(to: point(10, 13.5)); path.addLine(to: point(12.1, 15.6)); path.addLine(to: point(16.4, 11.4))

        case .save:
            rounded(&path, 4, 13.5, 16, 6.5, 1.3)
            path.move(to: point(12, 3.2)); path.addLine(to: point(12, 14.2))
            path.move(to: point(7.7, 9.9)); path.addLine(to: point(12, 14.2)); path.addLine(to: point(16.3, 9.9))

        case .sliders:
            path.move(to: point(4, 6)); path.addLine(to: point(20, 6)); path.addEllipse(in: area(8, 3.8, 4.4, 4.4))
            path.move(to: point(4, 12)); path.addLine(to: point(20, 12)); path.addEllipse(in: area(13.4, 9.8, 4.4, 4.4))
            path.move(to: point(4, 18)); path.addLine(to: point(20, 18)); path.addEllipse(in: area(6.1, 15.8, 4.4, 4.4))

        case .frameSelect:
            path.move(to: point(4, 9)); path.addLine(to: point(4, 4)); path.addLine(to: point(9, 4))
            path.move(to: point(15, 4)); path.addLine(to: point(20, 4)); path.addLine(to: point(20, 9))
            path.move(to: point(20, 15)); path.addLine(to: point(20, 20)); path.addLine(to: point(15, 20))
            path.move(to: point(9, 20)); path.addLine(to: point(4, 20)); path.addLine(to: point(4, 15))
            path.move(to: point(10.2, 15)); path.addLine(to: point(12.1, 16.9)); path.addLine(to: point(16.1, 12.9))

        case .film:
            rounded(&path, 3, 4, 18, 16, 2)
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
            rounded(&path, 3, 7, 15, 12, 1.8)
            rounded(&path, 7, 4, 14, 12, 1.8)
            path.move(to: point(10.5, 4)); path.addLine(to: point(10.5, 16))
            path.move(to: point(17.5, 4)); path.addLine(to: point(17.5, 16))

        case .plus:
            path.move(to: point(12, 4.5)); path.addLine(to: point(12, 19.5))
            path.move(to: point(4.5, 12)); path.addLine(to: point(19.5, 12))

        case .trash:
            path.move(to: point(5, 7)); path.addLine(to: point(19, 7))
            path.move(to: point(9.2, 4)); path.addLine(to: point(14.8, 4))
            rounded(&path, 6.5, 7, 11, 13, 1.5)
            path.move(to: point(10, 10)); path.addLine(to: point(10, 17)); path.move(to: point(14, 10)); path.addLine(to: point(14, 17))

        case .refresh:
            path.addArc(center: point(12, 12), radius: side * 7.4 / 24, startAngle: .degrees(42), endAngle: .degrees(334), clockwise: false)
            path.move(to: point(17.1, 5.7)); path.addLine(to: point(19.6, 5.8)); path.addLine(to: point(19.1, 8.3))

        case .pause:
            rounded(&path, 6.3, 4.5, 4.2, 15, 1.1)
            rounded(&path, 13.5, 4.5, 4.2, 15, 1.1)

        case .play:
            path.move(to: point(7.5, 4.6)); path.addLine(to: point(18.5, 12)); path.addLine(to: point(7.5, 19.4)); path.closeSubpath()
        }
        return path
    }
}
