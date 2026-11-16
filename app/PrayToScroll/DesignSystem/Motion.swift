import SwiftUI

/// The streak flame. Lit when today's prayer is done, embers when the streak is waiting for today.
struct StreakFlame: View {
    var streak: Int
    var lit: Bool = true
    var size: CGFloat = 64
    var showsNumber: Bool = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion || !lit)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let flicker = lit && !reduceMotion ? sin(t * 5.3) * 0.025 + sin(t * 8.9) * 0.015 : 0
            ZStack {
                if lit {
                    Circle()
                        .fill(RadialGradient(colors: [Palette.gold.opacity(0.45), .clear], center: .center, startRadius: 0, endRadius: size * 0.7))
                        .frame(width: size * 1.5, height: size * 1.5)
                        .offset(y: size * 0.12)
                }
                if let art = ArtAsset.image("FlameStreak") {
                    Image(uiImage: art)
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
                        .frame(width: size, height: size)
                        .saturation(lit ? 1 : 0)
                        .opacity(lit ? 1 : 0.5)
                        .scaleEffect(x: 1 - flicker * 0.4, y: 1 + flicker * 0.7, anchor: .bottom)
                } else {
                    FlameShape()
                        .fill(lit ? AnyShapeStyle(Palette.flameGradient)
                                  : AnyShapeStyle(LinearGradient(colors: [Color(hex: 0x8C93A3), Color(hex: 0x5B6375)], startPoint: .top, endPoint: .bottom)))
                        .frame(width: size * 0.8, height: size)
                        .scaleEffect(x: 1 - flicker * 0.6, y: 1 + flicker, anchor: .bottom)
                    FlameShape()
                        .fill(LinearGradient(colors: lit ? [Color.white, Palette.cream, Palette.warmGold] : [Color(hex: 0xD5D9E2), Color(hex: 0xA9AFBD)],
                                             startPoint: .top, endPoint: .bottom))
                        .frame(width: size * 0.46, height: size * 0.58)
                        .offset(y: size * 0.19)
                        .scaleEffect(x: 1, y: 1 - flicker * 0.8, anchor: .bottom)
                }
                if showsNumber {
                    Text("\(streak)")
                        .font(.system(size: size * (streak >= 100 ? 0.21 : 0.27), weight: .heavy, design: .serif))
                        .foregroundStyle(Palette.midnight)
                        .monospacedDigit()
                        .contentTransition(.numericText(value: Double(streak)))
                        .offset(x: ArtAsset.image("FlameStreak") == nil ? 0 : -size * 0.03,
                                y: ArtAsset.image("FlameStreak") == nil ? size * 0.27 : size * 0.2)
                        .minimumScaleFactor(0.5)
                }
            }
            .frame(width: size, height: size * 1.1)
        }
        .accessibilityElement()
        .accessibilityLabel(lit ? "\(streak) day streak" : "\(streak) day streak, pray today to keep it")
    }
}

/// Soft light motes drifting upward.
struct LightParticles: View {
    var count: Int = 40
    var color: Color = Palette.warmGold
    var speed: Double = 1
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var motes: [Mote] = []

    struct Mote {
        var x: Double
        var speed: Double
        var size: Double
        var phase: Double
        var drift: Double
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { context in
            Canvas { gc, size in
                let t = context.date.timeIntervalSinceReferenceDate
                for mote in motes {
                    let progress = (t * mote.speed * speed + mote.phase).truncatingRemainder(dividingBy: 1)
                    let y = size.height * (1.05 - progress * 1.1)
                    let x = mote.x * size.width + sin(t * mote.drift + mote.phase * 6.28) * 14
                    let alpha = sin(progress * .pi) * 0.85
                    let glowRect = CGRect(x: x - mote.size * 2, y: y - mote.size * 2, width: mote.size * 4, height: mote.size * 4)
                    gc.fill(Path(ellipseIn: glowRect), with: .color(color.opacity(alpha * 0.18)))
                    let rect = CGRect(x: x - mote.size / 2, y: y - mote.size / 2, width: mote.size, height: mote.size)
                    gc.fill(Path(ellipseIn: rect), with: .color(color.opacity(alpha)))
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear {
            if motes.isEmpty {
                motes = (0..<count).map { _ in
                    Mote(x: .random(in: 0...1), speed: .random(in: 0.025...0.07), size: .random(in: 1.5...4.5),
                         phase: .random(in: 0...1), drift: .random(in: 0.3...1.1))
                }
            }
        }
    }
}

/// The slow breathing light at the center of a prayer: 4 s in, 4 s out.
struct BreathingGlow: View {
    var size: CGFloat = 260
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    static func phase(at t: TimeInterval) -> Double {
        0.5 - 0.5 * cos(2 * .pi * t / 8)
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { context in
            let p = reduceMotion ? 0.6 : BreathingGlow.phase(at: context.date.timeIntervalSinceReferenceDate)
            ZStack {
                Circle()
                    .fill(RadialGradient(colors: [Palette.gold.opacity(0.32), Palette.gold.opacity(0.08), .clear],
                                         center: .center, startRadius: 0, endRadius: size * 0.62))
                    .scaleEffect(0.78 + 0.32 * p)
                Circle()
                    .fill(RadialGradient(colors: [Palette.warmGold.opacity(0.22), .clear], center: .center, startRadius: 0, endRadius: size * 0.32))
                    .scaleEffect(0.85 + 0.25 * p)
            }
            .frame(width: size * 1.3, height: size * 1.3)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// "Breathe in" / "Breathe out" synced to `BreathingGlow`.
struct BreathCue: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { context in
            let t = context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 8)
            Text(t < 4 ? "Breathe in" : "Breathe out")
                .font(.akFootnote.weight(.semibold))
                .tracking(1.2)
                .textCase(.uppercase)
                .foregroundStyle(Palette.warmGold.opacity(0.75))
                .contentTransition(.opacity)
                .animation(.easeInOut(duration: 0.35), value: t < 4)
        }
        .opacity(reduceMotion ? 0 : 1)
        .accessibilityHidden(true)
    }
}
