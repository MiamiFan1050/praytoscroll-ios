import SwiftUI

/// An arched doorway: a rectangle with a semicircular top.
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

/// A wax seal's rim: a disc with soft scallops, like pressed wax.
struct WaxSealShape: Shape {
    var bumps: Int = 12
    var depth: CGFloat = 0.08

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        let steps = max(24, bumps * 12)
        var path = Path()
        for i in 0...steps {
            let t = Double(i) / Double(steps) * 2 * .pi
            let r = radius * (1 - depth * CGFloat((1 - cos(Double(bumps) * t)) / 2))
            let point = CGPoint(x: center.x + r * CGFloat(sin(t)), y: center.y - r * CGFloat(cos(t)))
            if i == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        path.closeSubpath()
        return path
    }
}

/// The open sheet of a scroll: straight top and bottom (they meet the rollers), gently curved-in sides.
struct ParchmentShape: Shape {
    func path(in rect: CGRect) -> Path {
        let bow = rect.width * 0.07
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.maxY), control: CGPoint(x: rect.maxX - bow, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.minY), control: CGPoint(x: rect.minX + bow, y: rect.midY))
        path.closeSubpath()
        return path
    }
}

/// The Pray to Scroll mark: an open scroll between two gold rollers, sealed with red wax and a gold cross.
/// Our own motif (it echoes the scroll in the app icon). `open` below 1 draws the rollers closer together,
/// as if the scroll were still partly rolled; the Amen button unrolls it as you hold.
struct PrayToScrollMark: View {
    var glow: Bool = true
    var open: CGFloat = 1

    static let aspect: CGFloat = 0.74
    private static let waxLight = Color(hex: 0xD45A45)
    private static let wax = Color(hex: 0xA9352A)
    private static let waxDeep = Color(hex: 0x6E1C17)

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let openness = min(1, max(0.35, open))
            let rollerHeight = h * 0.115
            let span = (h - rollerHeight) * openness       // roller centre to roller centre
            let midY = h / 2
            let sheetWidth = w * 0.72
            let seal = w * 0.44
            ZStack {
                ParchmentShape()
                    .fill(LinearGradient(colors: [Palette.cream, Palette.parchment, Color(hex: 0xE4CFA6)],
                                         startPoint: .top, endPoint: .bottom))
                    .frame(width: sheetWidth, height: span)
                    .position(x: w / 2, y: midY)
                // Two lines of writing above the seal (too small to matter on the widget, so they fade out there).
                VStack(spacing: h * 0.05) {
                    Capsule().frame(width: sheetWidth * 0.6, height: max(0.5, h * 0.022))
                    Capsule().frame(width: sheetWidth * 0.42, height: max(0.5, h * 0.022))
                }
                .foregroundStyle(Palette.deepGold.opacity(h > 30 ? 0.4 : 0))
                .position(x: w / 2, y: midY - span * 0.26)
                .opacity(openness > 0.8 ? 1 : 0)
                ZStack {
                    WaxSealShape()
                        .fill(RadialGradient(colors: [Self.waxLight, Self.wax, Self.waxDeep],
                                             center: UnitPoint(x: 0.36, y: 0.3), startRadius: 0, endRadius: seal * 0.62))
                    Circle()
                        .strokeBorder(Self.waxDeep.opacity(0.6), lineWidth: max(0.5, seal * 0.045))
                        .padding(seal * 0.15)
                    CrossShape(armRatio: 0.27)
                        .fill(Palette.goldGradient)
                        .frame(width: seal * 0.34, height: seal * 0.48)
                }
                .frame(width: seal, height: seal)
                .shadow(color: .black.opacity(0.25), radius: seal * 0.06, y: seal * 0.04)
                .position(x: w / 2, y: midY + span * (openness > 0.8 ? 0.12 : 0))
                roller(width: w, height: rollerHeight).position(x: w / 2, y: midY - span / 2)
                roller(width: w, height: rollerHeight).position(x: w / 2, y: midY + span / 2)
            }
            .frame(width: w, height: h)
            .shadow(color: Palette.gold.opacity(glow ? 0.5 : 0), radius: glow ? w * 0.12 : 0)
        }
        .aspectRatio(Self.aspect, contentMode: .fit)
        .accessibilityHidden(true)
    }

    /// A gold rod with a round knob at each end.
    private func roller(width: CGFloat, height: CGFloat) -> some View {
        let knob = height * 1.2
        let knobFill = RadialGradient(colors: [Palette.warmGold, Palette.gold, Palette.deepGold],
                                      center: UnitPoint(x: 0.35, y: 0.3), startRadius: 0, endRadius: knob * 0.7)
        return ZStack {
            Capsule()
                .fill(LinearGradient(colors: [Color(hex: 0xFBE7B0), Palette.gold, Palette.deepGold], startPoint: .top, endPoint: .bottom))
                .frame(width: width - knob, height: height)
            HStack(spacing: 0) {
                Circle().fill(knobFill).frame(width: knob, height: knob)
                Spacer(minLength: 0)
                Circle().fill(knobFill).frame(width: knob, height: knob)
            }
        }
        .frame(width: width, height: knob)
    }
}
