import SwiftUI
import UIKit

/// The praying lamb with a gold key. Uses the art in the asset catalog ("Mascot", "Mascot-<pose>")
/// when it's there; until then, a lamb drawn in SwiftUI.
struct MascotView: View {
    enum Pose: String { case praying, celebrating, waving, sleeping }
    var pose: Pose = .praying
    var size: CGFloat = 160

    var body: some View {
        Group {
            if let image = MascotView.image(for: pose) {
                Image(uiImage: image)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
            } else {
                DrawnLamb(pose: pose)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    static func image(for pose: Pose) -> UIImage? {
        UIImage(named: "Mascot-\(pose.rawValue)") ?? UIImage(named: "Mascot")
    }
}

/// Placeholder lamb: fluffy wool, closed eyes, little hooves together, a gold key on a chain.
private struct DrawnLamb: View {
    var pose: MascotView.Pose
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height)
            TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { context in
                let t = context.date.timeIntervalSinceReferenceDate
                let bob = reduceMotion ? 0 : sin(t * 1.6) * s * 0.012
                ZStack {
                    // soft halo
                    Circle()
                        .fill(RadialGradient(colors: [Palette.gold.opacity(0.28), .clear], center: .center, startRadius: 0, endRadius: s * 0.5))
                    // wool body
                    woolCluster(s: s, center: CGPoint(x: 0, y: s * 0.17), radius: s * 0.27, puffs: 9)
                    // head wool tuft
                    woolCluster(s: s, center: CGPoint(x: 0, y: -s * 0.25), radius: s * 0.11, puffs: 6)
                    // ears
                    ear(s: s).rotationEffect(.degrees(-32)).offset(x: -s * 0.2, y: -s * 0.1)
                    ear(s: s).scaleEffect(x: -1).rotationEffect(.degrees(32)).offset(x: s * 0.2, y: -s * 0.1)
                    // face
                    Ellipse()
                        .fill(LinearGradient(colors: [Color(hex: 0xF4E6D6), Color(hex: 0xE6CFB6)], startPoint: .top, endPoint: .bottom))
                        .frame(width: s * 0.3, height: s * 0.34)
                        .offset(y: -s * 0.08)
                    // eyes: closed in prayer, open and smiling when celebrating
                    eyes(s: s).offset(y: -s * 0.1)
                    // blush
                    HStack(spacing: s * 0.13) {
                        Circle().fill(Palette.rose.opacity(0.75)).frame(width: s * 0.05)
                        Circle().fill(Palette.rose.opacity(0.75)).frame(width: s * 0.05)
                    }
                    .offset(y: -s * 0.04)
                    // little smile
                    SmileShape()
                        .stroke(Color(hex: 0x6B4A3A), style: StrokeStyle(lineWidth: s * 0.012, lineCap: .round))
                        .frame(width: s * 0.06, height: s * 0.025)
                        .offset(y: s * 0.0)
                    // gold chain + key
                    Capsule()
                        .stroke(Palette.goldGradient, lineWidth: s * 0.012)
                        .frame(width: s * 0.22, height: s * 0.08)
                        .offset(y: s * 0.1)
                    PrayToScrollMark(glow: true)
                        .frame(height: s * 0.16)
                        .offset(y: s * 0.21)
                    // hooves together
                    hooves(s: s).offset(y: pose == .celebrating ? -s * 0.02 : s * 0.13)
                }
                .offset(y: bob)
                .frame(width: s, height: s)
            }
        }
    }

    private func woolCluster(s: CGFloat, center: CGPoint, radius: CGFloat, puffs: Int) -> some View {
        ZStack {
            Circle().fill(Color(hex: 0xFFFDF8)).frame(width: radius * 1.6, height: radius * 1.6)
            ForEach(0..<puffs, id: \.self) { i in
                let angle = Double(i) / Double(puffs) * 2 * .pi
                Circle()
                    .fill(LinearGradient(colors: [Color.white, Color(hex: 0xF1E8DA)], startPoint: .top, endPoint: .bottom))
                    .frame(width: radius * 0.95, height: radius * 0.95)
                    .offset(x: cos(angle) * radius * 0.62, y: sin(angle) * radius * 0.5)
            }
        }
        .shadow(color: Color.black.opacity(0.12), radius: s * 0.02, y: s * 0.01)
        .offset(x: center.x, y: center.y)
    }

    private func ear(s: CGFloat) -> some View {
        ZStack {
            Ellipse().fill(Color(hex: 0xE6CFB6)).frame(width: s * 0.16, height: s * 0.07)
            Ellipse().fill(Palette.rose.opacity(0.7)).frame(width: s * 0.1, height: s * 0.035)
        }
    }

    @ViewBuilder
    private func eyes(s: CGFloat) -> some View {
        HStack(spacing: s * 0.08) {
            ForEach(0..<2, id: \.self) { _ in
                if pose == .celebrating || pose == .waving {
                    SmileShape()
                        .stroke(Color(hex: 0x3B2A22), style: StrokeStyle(lineWidth: s * 0.014, lineCap: .round))
                        .frame(width: s * 0.05, height: s * 0.022)
                        .rotationEffect(.degrees(180))
                } else {
                    SmileShape()
                        .stroke(Color(hex: 0x3B2A22), style: StrokeStyle(lineWidth: s * 0.014, lineCap: .round))
                        .frame(width: s * 0.05, height: s * 0.02)
                }
            }
        }
    }

    private func hooves(s: CGFloat) -> some View {
        HStack(spacing: -s * 0.012) {
            RoundedRectangle(cornerRadius: s * 0.03, style: .continuous)
                .fill(LinearGradient(colors: [Color(hex: 0xE6CFB6), Color(hex: 0xC9AE92)], startPoint: .top, endPoint: .bottom))
                .frame(width: s * 0.06, height: s * 0.11)
                .rotationEffect(.degrees(14), anchor: .bottom)
            RoundedRectangle(cornerRadius: s * 0.03, style: .continuous)
                .fill(LinearGradient(colors: [Color(hex: 0xE6CFB6), Color(hex: 0xC9AE92)], startPoint: .top, endPoint: .bottom))
                .frame(width: s * 0.06, height: s * 0.11)
                .rotationEffect(.degrees(-14), anchor: .bottom)
        }
    }
}

/// A shallow U-shaped arc (smile / closed eye).
struct SmileShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY), control: CGPoint(x: rect.midX, y: rect.maxY * 2 - rect.minY))
        return path
    }
}
