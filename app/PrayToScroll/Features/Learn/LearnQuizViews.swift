import SwiftUI

/// The choices of a Learn quiz, in Scroll the Word's capsule style. After a pick: the right one turns gold, a miss
/// turns rose (never red), the rest fade.
struct LearnChoiceList: View {
    let choices: [String]
    let right: String
    var picked: String?
    var idPrefix: String
    var onPick: (String) -> Void

    var body: some View {
        VStack(spacing: 10) {
            ForEach(Array(choices.enumerated()), id: \.offset) { index, choice in
                let revealed = picked != nil
                let isRight = choice == right
                let isPicked = picked == choice
                Button {
                    guard picked == nil else { return }
                    onPick(choice)
                } label: {
                    HStack {
                        Text(choice)
                            .font(.akHeadline)
                            .multilineTextAlignment(.leading)
                        Spacer(minLength: 8)
                        if revealed && isRight { Image(systemName: "checkmark.circle.fill") }
                        if revealed && isPicked && !isRight { Image(systemName: "xmark.circle.fill") }
                    }
                    .foregroundStyle(revealed && isRight ? Palette.midnight : Palette.cream)
                    .padding(.horizontal, 18)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background {
                        if revealed && isRight {
                            Capsule().fill(Palette.goldButton)
                        } else if revealed && isPicked {
                            Capsule().fill(Palette.rose.opacity(0.35))
                        } else {
                            Capsule().fill(.ultraThinMaterial)
                        }
                    }
                    .opacity(revealed && !isRight && !isPicked ? 0.55 : 1)
                }
                .buttonStyle(PressScaleStyle(scale: 0.97))
                .accessibilityLabel(choice)
                .accessibilityValue(revealed ? (isRight ? "Right answer" : (isPicked ? "Your pick" : "")) : "")
                .accessibilityIdentifier("\(idPrefix).\(index)")
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: picked)
    }
}

/// After an answer: right or not (kindly), and what the verse says.
struct LearnAnswerNote: View {
    let right: Bool
    let line: String
    let explain: String
    let ref: String
    var id: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(line, systemImage: right ? "sparkles" : "book.fill")
                .font(.akSubheadlineSemibold)
                .foregroundStyle(right ? Palette.warmGold : Palette.cream)
            if !explain.isEmpty {
                Text(explain)
                    .font(.system(.callout, design: .rounded))
                    .foregroundStyle(Palette.cream.opacity(0.88))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text(ref)
                .font(.system(.subheadline, design: .serif, weight: .semibold))
                .foregroundStyle(Palette.warmGold)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(.ultraThinMaterial))
        .transition(.opacity.combined(with: .move(edge: .bottom)))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(id)
    }
}

/// Gold capsule (primary) and glass capsule (secondary) buttons for Learn's dark screens.
struct LearnButton: View {
    enum Style { case gold, glass }
    let title: String
    var symbol: String?
    var style: Style = .gold
    var id: String
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            HStack(spacing: 8) {
                if let symbol { Image(systemName: symbol) }
                Text(title).lineLimit(2).multilineTextAlignment(.center)
            }
            .font(.akHeadline)
            .foregroundStyle(style == .gold ? Palette.midnight : Palette.cream)
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background {
                if style == .gold { Capsule().fill(Palette.goldButton) } else { Capsule().fill(.ultraThinMaterial) }
            }
        }
        .buttonStyle(PressScaleStyle())
        .accessibilityIdentifier(id)
    }
}

/// The round close button Learn's full-screen pages use (labelled "Close", like the app's other covers).
struct LearnCloseButton: View {
    var id: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Palette.cream)
                .frame(width: 44, height: 44)
                .background(Circle().fill(.ultraThinMaterial))
        }
        .buttonStyle(PressScaleStyle(scale: 0.92))
        .accessibilityLabel("Close")
        .accessibilityIdentifier(id)
    }
}

/// XP as a small gold chip.
struct XPChip: View {
    let xp: Int

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "sparkle")
            Text("\(xp) XP").monospacedDigit().contentTransition(.numericText())
        }
        .font(.akSubheadlineSemibold)
        .foregroundStyle(Palette.warmGold)
        .padding(.horizontal, 12)
        .frame(minHeight: 34)
        .background(Capsule().fill(.ultraThinMaterial))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(xp) XP")
    }
}
