import SwiftUI

/// An arched doorway: a rectangle with a semicircular top. The "door" the key opens.
struct ArchShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let radius = min(rect.width / 2, rect.height)
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + radius))
        path.addArc(center: CGPoint(x: rect.midX, y: rect.minY + radius), radius: radius,
                    startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

/// A Latin cross with softly rounded arms.
struct CrossShape: Shape {
    var armRatio: CGFloat = 0.22
    func path(in rect: CGRect) -> Path {
        let bar = rect.width * armRatio
        let vertical = CGRect(x: rect.midX - bar / 2, y: rect.minY, width: bar, height: rect.height)
        let horizontalY = rect.minY + rect.height * 0.30
        let horizontal = CGRect(x: rect.minX, y: horizontalY - bar / 2, width: rect.width, height: bar)
        var path = Path()
        path.addRoundedRect(in: vertical, cornerSize: CGSize(width: bar / 2, height: bar / 2))
        path.addRoundedRect(in: horizontal, cornerSize: CGSize(width: bar / 2, height: bar / 2))
        return path
    }
}

/// A candle-like flame used for streaks.
struct FlameShape: Shape {
    func path(in rect: CGRect) -> Path {
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * rect.width, y: rect.minY + y * rect.height)
        }
        var path = Path()
        path.move(to: p(0.52, 0.0))
        path.addCurve(to: p(0.94, 0.64), control1: p(0.62, 0.20), control2: p(0.94, 0.38))
        path.addCurve(to: p(0.50, 1.0), control1: p(0.94, 0.86), control2: p(0.74, 1.0))
        path.addCurve(to: p(0.06, 0.64), control1: p(0.26, 1.0), control2: p(0.06, 0.86))
        path.addCurve(to: p(0.28, 0.26), control1: p(0.06, 0.48), control2: p(0.18, 0.36))
        path.addCurve(to: p(0.44, 0.46), control1: p(0.30, 0.36), control2: p(0.36, 0.44))
        path.addCurve(to: p(0.52, 0.0), control1: p(0.40, 0.30), control2: p(0.42, 0.14))
        path.closeSubpath()
        return path
    }
}

/// The key's shaft, collar and teeth (the bow is drawn with `ArchShape`).
struct KeyShaftShape: Shape {
    func path(in rect: CGRect) -> Path {
        // Designed in a 100 x 84 box: collar at the top, shaft down the middle, two teeth on the right.
        func r(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> CGRect {
            CGRect(x: rect.minX + x / 100 * rect.width, y: rect.minY + y / 84 * rect.height,
                   width: w / 100 * rect.width, height: h / 84 * rect.height)
        }
        let corner = CGSize(width: rect.width * 0.03, height: rect.width * 0.03)
        var path = Path()
        path.addRoundedRect(in: r(32, 0, 36, 9), cornerSize: corner)       // collar
        path.addRoundedRect(in: r(43, 4, 14, 80), cornerSize: corner)      // shaft
        path.addRoundedRect(in: r(55, 50, 20, 10), cornerSize: corner)     // tooth 1
        path.addRoundedRect(in: r(55, 68, 14, 10), cornerSize: corner)     // tooth 2
        return path
    }
}

/// The PrayToScroll mark: a gold key whose bow is an arched doorway with a small cross of light inside.
struct PrayToScrollMark: View {
    var glow: Bool = true
    var lineWidthRatio: CGFloat = 0.09

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let bowHeight = h * 0.56
            let line = w * lineWidthRatio
            ZStack(alignment: .top) {
                // Light pouring through the doorway.
                ArchShape()
                    .fill(RadialGradient(colors: [Palette.cream, Palette.warmGold.opacity(0.85), Palette.gold.opacity(0.25)],
                                         center: UnitPoint(x: 0.5, y: 0.62), startRadius: 0, endRadius: w * 0.55))
                    .frame(width: w * 0.80 - line, height: bowHeight - line)
                    .offset(y: line / 2)
                    .opacity(glow ? 0.95 : 0.75)
                ArchShape()
                    .stroke(Palette.goldGradient, style: StrokeStyle(lineWidth: line, lineJoin: .round))
                    .frame(width: w * 0.80, height: bowHeight)
                CrossShape(armRatio: 0.24)
                    .fill(Color.white)
                    .frame(width: w * 0.24, height: bowHeight * 0.44)
                    .offset(y: bowHeight * 0.34)
                    .shadow(color: Palette.warmGold.opacity(glow ? 0.9 : 0), radius: w * 0.06)
                KeyShaftShape()
                    .fill(Palette.goldGradient)
                    .frame(width: w * 0.8, height: h - bowHeight + line / 2)
                    .offset(y: bowHeight - line / 2)
            }
            .frame(width: w, height: h)
            .shadow(color: Palette.gold.opacity(glow ? 0.55 : 0), radius: glow ? w * 0.12 : 0)
        }
        .aspectRatio(0.62, contentMode: .fit)
        .accessibilityHidden(true)
    }
}
