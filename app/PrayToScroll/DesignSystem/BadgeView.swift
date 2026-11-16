import SwiftUI

/// A milestone medallion: gold when earned, quiet outline when still ahead.
struct BadgeView: View {
    let milestone: Int
    var earned: Bool
    var size: CGFloat = 72

    var body: some View {
        ZStack {
            if earned {
                Circle()
                    .fill(RadialGradient(colors: [Palette.gold.opacity(0.35), .clear], center: .center, startRadius: 0, endRadius: size * 0.7))
                    .frame(width: size * 1.35, height: size * 1.35)
            }
            // scalloped seal
            ForEach(0..<12, id: \.self) { i in
                Circle()
                    .fill(earned ? AnyShapeStyle(Palette.goldGradient) : AnyShapeStyle(Color.white.opacity(0.08)))
                    .frame(width: size * 0.3, height: size * 0.3)
                    .offset(y: -size * 0.36)
                    .rotationEffect(.degrees(Double(i) * 30))
            }
            Circle()
                .fill(earned ? AnyShapeStyle(Palette.goldGradient) : AnyShapeStyle(Color.white.opacity(0.08)))
                .frame(width: size * 0.84, height: size * 0.84)
            Circle()
                .fill(earned ? AnyShapeStyle(LinearGradient(colors: [Color(hex: 0x23365A), Palette.midnight], startPoint: .top, endPoint: .bottom))
                             : AnyShapeStyle(Theme.surfaceSolid))
                .frame(width: size * 0.68, height: size * 0.68)
                .overlay(Circle().strokeBorder(earned ? Palette.warmGold.opacity(0.6) : Theme.stroke, lineWidth: 1))
            VStack(spacing: size * 0.01) {
                Image(systemName: MilestoneEngine.symbol(for: milestone))
                    .font(.system(size: size * 0.2, weight: .semibold))
                    .foregroundStyle(earned ? Palette.warmGold : Theme.textTertiary)
                Text("\(milestone)")
                    .font(.system(size: size * 0.2, weight: .bold, design: .serif))
                    .foregroundStyle(earned ? Palette.cream : Theme.textTertiary)
            }
        }
        .frame(width: size, height: size)
        .accessibilityElement()
        .accessibilityLabel("\(MilestoneEngine.title(for: milestone)), \(milestone) days, \(earned ? "earned" : "not yet earned")")
    }
}
