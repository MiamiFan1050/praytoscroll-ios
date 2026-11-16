import SwiftUI

/// Read a verse / Devotional: the verse with its reference, our words under it, and (for a devotional) a one-line
/// prayer. Scrolls when it's longer than the screen; Amen waits for the minimum read time.
struct ReadingStepView: View {
    let card: ReadingCard
    let scale: CGFloat
    @ScaledMetric(relativeTo: .title3) private var verseBase: CGFloat = 21
    @ScaledMetric(relativeTo: .body) private var bodyBase: CGFloat = 17

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                if !card.title.isEmpty {
                    Text(card.title)
                        .font(.akTitle2)
                        .foregroundStyle(Palette.cream)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityIdentifier("reading.title")
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text(card.text)
                        .font(.system(size: verseBase * scale, weight: .regular, design: .serif))
                        .foregroundStyle(Palette.cream)
                        .lineSpacing(5)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("reading.text")
                    Text(card.ref)
                        .font(.akSubheadlineSemibold)
                        .foregroundStyle(Palette.warmGold)
                        .accessibilityIdentifier("reading.ref")
                }
                .padding(.leading, 14)
                .overlay(alignment: .leading) {
                    Capsule().fill(Palette.gold.opacity(0.7)).frame(width: 3)
                }
                if !card.body.isEmpty {
                    Text(card.body)
                        .font(.system(size: bodyBase * scale, design: .rounded))
                        .foregroundStyle(Palette.cream.opacity(0.86))
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("reading.body")
                }
                if !card.closing.isEmpty {
                    Text(card.closing)
                        .font(.system(size: bodyBase * scale, design: .serif).italic())
                        .foregroundStyle(Palette.warmGold)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("reading.prayer")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 6)
        }
        .scrollBounceBehavior(.basedOnSize)
    }
}

/// Prayer · Read a verse · Devotional, on the gate screen when "Ask me after each prayer" is on.
struct UnlockMethodPicker: View {
    @Bindable var flow: PrayerFlow

    var body: some View {
        HStack(spacing: 8) {
            ForEach(UnlockMethod.allCases) { method in
                let isOn = flow.method == method
                Button {
                    withAnimation(.easeInOut(duration: 0.3)) { flow.switchMethod(to: method) }
                } label: {
                    Chip(text: method.title, isSelected: isOn, tint: Palette.warmGold)
                }
                .buttonStyle(PressScaleStyle())
                .accessibilityAddTraits(isOn ? .isSelected : [])
                .accessibilityIdentifier("session.method.\(method.rawValue)")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Unlock with")
    }
}
