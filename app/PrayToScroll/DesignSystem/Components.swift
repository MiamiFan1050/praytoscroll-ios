import SwiftUI

// MARK: - Backgrounds

/// The app's canvas: a deep midnight gradient with warm light falling from above (cream in light mode).
struct AppBackground: View {
    @Environment(\.colorScheme) private var scheme
    var glowStrength: Double = 1

    var body: some View {
        ZStack {
            if scheme == .dark {
                LinearGradient(colors: [Color(hex: 0x111C30), Palette.midnight, Palette.midnightDeep],
                               startPoint: .top, endPoint: .bottom)
                RadialGradient(colors: [Palette.gold.opacity(0.16 * glowStrength), .clear],
                               center: UnitPoint(x: 0.5, y: -0.05), startRadius: 0, endRadius: 520)
                RadialGradient(colors: [Color(hex: 0x2A3F66).opacity(0.35), .clear],
                               center: UnitPoint(x: 0.0, y: 1.0), startRadius: 0, endRadius: 480)
            } else {
                LinearGradient(colors: [Color(hex: 0xFFFBF3), Palette.cream, Palette.parchment],
                               startPoint: .top, endPoint: .bottom)
                RadialGradient(colors: [Palette.warmGold.opacity(0.35 * glowStrength), .clear],
                               center: UnitPoint(x: 0.5, y: -0.05), startRadius: 0, endRadius: 520)
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - Cards

struct CardBackground: View {
    @Environment(\.colorScheme) private var scheme
    var cornerRadius: CGFloat = 24
    var highlighted: Bool = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        shape
            .fill(Theme.surface)
            .overlay(
                shape.strokeBorder(
                    LinearGradient(colors: highlighted
                                   ? [Palette.gold.opacity(0.75), Palette.gold.opacity(0.15)]
                                   : [Color.white.opacity(scheme == .dark ? 0.12 : 0.9), Theme.stroke],
                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: highlighted ? 1.2 : 1)
            )
            .shadow(color: Theme.shadow, radius: scheme == .dark ? 18 : 14, x: 0, y: scheme == .dark ? 10 : 6)
    }
}

/// The signature translucent card.
struct GlassCard<Content: View>: View {
    var padding: CGFloat = 18
    var cornerRadius: CGFloat = 24
    var highlighted: Bool = false
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(CardBackground(cornerRadius: cornerRadius, highlighted: highlighted))
    }
}

extension View {
    func akCard(padding: CGFloat = 18, cornerRadius: CGFloat = 24, highlighted: Bool = false) -> some View {
        self.padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(CardBackground(cornerRadius: cornerRadius, highlighted: highlighted))
    }
}

// MARK: - Buttons

/// Press-scale feedback for any tappable card.
struct PressScaleStyle: ButtonStyle {
    var scale: CGFloat = 0.97
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .animation(.spring(response: 0.28, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

struct GoldButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    var height: CGFloat = 58

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.akHeadline)
            .foregroundStyle(Palette.midnight)
            .frame(maxWidth: .infinity, minHeight: height)
            .padding(.horizontal, 20)
            .background(
                Capsule(style: .continuous)
                    .fill(Palette.goldButton)
                    .overlay(Capsule(style: .continuous).strokeBorder(Color.white.opacity(0.45), lineWidth: 1).blendMode(.overlay))
                    .shadow(color: Palette.gold.opacity(isEnabled ? 0.45 : 0), radius: configuration.isPressed ? 8 : 18, y: configuration.isPressed ? 3 : 8)
            )
            .opacity(isEnabled ? 1 : 0.45)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

struct QuietButtonStyle: ButtonStyle {
    var height: CGFloat = 54
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.akHeadline)
            .foregroundStyle(Theme.textPrimary)
            .frame(maxWidth: .infinity, minHeight: height)
            .padding(.horizontal, 20)
            .background(
                Capsule(style: .continuous)
                    .fill(Theme.surfaceRaised.opacity(0.9))
                    .overlay(Capsule(style: .continuous).strokeBorder(Theme.strokeStrong, lineWidth: 1))
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

/// The gold call-to-action button with a haptic tap.
struct PrimaryButton: View {
    let title: String
    var systemImage: String?
    var height: CGFloat = 58
    let action: () -> Void

    init(_ title: String, systemImage: String? = nil, height: CGFloat = 58, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.height = height
        self.action = action
    }

    var body: some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            HStack(spacing: 10) {
                if let systemImage { Image(systemName: systemImage).font(.body.weight(.semibold)) }
                Text(title).lineLimit(2).multilineTextAlignment(.center)
            }
        }
        .buttonStyle(GoldButtonStyle(height: height))
    }
}

struct SecondaryButton: View {
    let title: String
    var systemImage: String?
    let action: () -> Void

    init(_ title: String, systemImage: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.action = action
    }

    var body: some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            HStack(spacing: 8) {
                if let systemImage { Image(systemName: systemImage) }
                Text(title).lineLimit(2).multilineTextAlignment(.center)
            }
        }
        .buttonStyle(QuietButtonStyle())
    }
}

/// Round icon button used in headers (settings, close, share).
struct CircleIconButton: View {
    let systemImage: String
    var label: String
    var size: CGFloat = 44
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            Image(systemName: systemImage)
                .font(.system(size: size * 0.38, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
                .frame(width: size, height: size)
                .background(Circle().fill(Theme.surfaceRaised.opacity(0.85)))
                .overlay(Circle().strokeBorder(Theme.stroke, lineWidth: 1))
        }
        .buttonStyle(PressScaleStyle(scale: 0.92))
        .accessibilityLabel(label)
    }
}

// MARK: - Small pieces

struct Chip: View {
    let text: String
    var systemImage: String?
    var isSelected: Bool = false
    var tint: Color = Theme.goldText

    var body: some View {
        HStack(spacing: 6) {
            if let systemImage { Image(systemName: systemImage).font(.caption.weight(.bold)) }
            Text(text).font(.akCaption).lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .foregroundStyle(isSelected ? Palette.midnight : tint)
        .background(
            Capsule(style: .continuous)
                .fill(isSelected ? AnyShapeStyle(Palette.goldButton) : AnyShapeStyle(tint.opacity(0.13)))
        )
        .overlay(Capsule(style: .continuous).strokeBorder(isSelected ? Color.clear : tint.opacity(0.25), lineWidth: 1))
    }
}

struct StatTile: View {
    let value: String
    let label: String
    var systemImage: String
    var tint: Color = Theme.goldIcon

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 32, height: 32)
                .background(Circle().fill(tint.opacity(0.14)))
            Text(value)
                .font(.system(.title, design: .serif, weight: .bold))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .contentTransition(.numericText())
            Text(label)
                .font(.akFootnote)
                .foregroundStyle(Theme.textSecondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(CardBackground(cornerRadius: 22))
        .accessibilityElement(children: .combine)
    }
}

struct ProgressRing: View {
    var progress: Double
    var lineWidth: CGFloat = 10
    var track: Color = Theme.stroke
    var gradient: AngularGradient = AngularGradient(colors: [Palette.warmGold, Palette.gold, Palette.deepGold, Palette.warmGold],
                                                     center: .center, startAngle: .degrees(-90), endAngle: .degrees(270))

    var body: some View {
        ZStack {
            Circle().stroke(track, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0.0001, min(1, progress)))
                .stroke(gradient, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .shadow(color: Palette.gold.opacity(0.35), radius: lineWidth * 0.6)
        }
        .animation(.easeInOut(duration: 0.6), value: progress)
    }
}

struct SectionHeader: View {
    let title: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.akTitle3)
                .foregroundStyle(Theme.textPrimary)
            Spacer()
            if let actionTitle, let action {
                Button(actionTitle) {
                    Haptics.tap()
                    action()
                }
                .font(.akSubheadlineSemibold)
                .foregroundStyle(Theme.goldText)
                .frame(minHeight: 44)
            }
        }
        .accessibilityAddTraits(.isHeader)
    }
}

/// Monogram tile for a gated app (no third-party logos).
struct AppTile: View {
    let app: GatedApp
    var size: CGFloat = 52

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.27, style: .continuous)
                .fill(LinearGradient(colors: [Color(hex: app.colorHex), Color(hex: app.secondaryHex)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
            RoundedRectangle(cornerRadius: size * 0.27, style: .continuous)
                .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
            Text(app.monogram)
                .font(.system(size: size * 0.44, weight: .bold, design: .rounded))
                .foregroundStyle(app.id == "snapchat" ? Palette.midnight : .white)
                .minimumScaleFactor(0.5)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// Person avatar: emoji, or initials on a soft color.
struct Avatar: View {
    let name: String
    var emoji: String = ""
    var colorIndex: Int = 0
    var size: CGFloat = 44

    static let colors: [(UInt32, UInt32)] = [
        (0xE9B949, 0xB8862B), (0xA8C3A0, 0x6F9466), (0xE7A6A1, 0xC0716B),
        (0x8FA9E0, 0x5B76B5), (0xC7A6E0, 0x9370B8), (0xF0B27A, 0xC9814A),
    ]

    var body: some View {
        let pair = Avatar.colors[abs(colorIndex) % Avatar.colors.count]
        ZStack {
            Circle().fill(LinearGradient(colors: [Color(hex: pair.0), Color(hex: pair.1)], startPoint: .topLeading, endPoint: .bottomTrailing))
            if !emoji.isEmpty {
                Text(emoji).font(.system(size: size * 0.5))
            } else {
                Text(initials)
                    .font(.system(size: size * 0.38, weight: .bold, design: .rounded))
                    .foregroundStyle(Palette.midnight.opacity(0.85))
            }
        }
        .frame(width: size, height: size)
        .overlay(Circle().strokeBorder(Color.white.opacity(0.22), lineWidth: 1))
        .accessibilityHidden(true)
    }

    private var initials: String {
        let letters = name.split(separator: " ").prefix(2).compactMap(\.first).map { String($0).uppercased() }
        return letters.isEmpty ? "?" : letters.joined()
    }
}

/// A rounded square holding an SF Symbol, used in lists and settings.
struct IconBadge: View {
    let systemImage: String
    var tint: Color = Theme.goldIcon
    var size: CGFloat = 36

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: size * 0.44, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: size, height: size)
            .background(RoundedRectangle(cornerRadius: size * 0.3, style: .continuous).fill(tint.opacity(0.15)))
            .accessibilityHidden(true)
    }
}

/// Warm empty state with a drawn doorway illustration.
struct EmptyState: View {
    let title: String
    let message: String
    var systemImage: String = "sparkles"
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: 16) {
            DoorwayIllustration(symbol: systemImage)
                .frame(width: 150, height: 150)
            Text(title)
                .font(.akTitle3)
                .foregroundStyle(Theme.textPrimary)
                .multilineTextAlignment(.center)
            Text(message)
                .font(.akCallout)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            if let actionTitle, let action {
                PrimaryButton(actionTitle, action: action)
                    .frame(maxWidth: 280)
                    .padding(.top, 4)
            }
        }
        .padding(.vertical, 28)
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity)
    }
}

/// An arched doorway with light, rays and a symbol: the house illustration style.
struct DoorwayIllustration: View {
    var symbol: String = "sparkles"

    var body: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(colors: [Palette.gold.opacity(0.30), .clear], center: .center, startRadius: 4, endRadius: 75))
            ForEach(0..<12, id: \.self) { i in
                Capsule()
                    .fill(Palette.warmGold.opacity(i.isMultiple(of: 2) ? 0.35 : 0.18))
                    .frame(width: 2, height: i.isMultiple(of: 2) ? 22 : 14)
                    .offset(y: -62)
                    .rotationEffect(.degrees(Double(i) * 30))
            }
            ArchShape()
                .fill(LinearGradient(colors: [Palette.cream, Palette.warmGold, Palette.gold.opacity(0.7)], startPoint: .top, endPoint: .bottom))
                .frame(width: 58, height: 80)
                .shadow(color: Palette.gold.opacity(0.6), radius: 16)
            ArchShape()
                .stroke(Palette.goldGradient, lineWidth: 4)
                .frame(width: 70, height: 90)
                .offset(y: -1)
            Image(systemName: symbol)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Palette.deepGold)
                .offset(y: 10)
            // the floor line
            Capsule()
                .fill(Palette.gold.opacity(0.35))
                .frame(width: 110, height: 2)
                .offset(y: 46)
        }
        .accessibilityHidden(true)
    }
}
