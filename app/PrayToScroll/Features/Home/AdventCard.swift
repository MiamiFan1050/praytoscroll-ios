import SwiftUI

/// Advent (Nov 29 – Dec 24 only): today's reading, a prompt, and how many Advent days you've prayed.
struct AdventCard: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        if let today = model.adventToday() {
            let total = model.content.advent.count
            let prayed = model.adventDaysPrayed()
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("Advent · Day \(today.index + 1) of \(total)", systemImage: "star.fill")
                        .font(.akOverline)
                        .tracking(1.2)
                        .textCase(.uppercase)
                        .foregroundStyle(Theme.goldText)
                    Spacer()
                    Chip(text: today.day.week, tint: Theme.sageText)
                }
                Text(today.day.title)
                    .font(.akTitle3)
                    .foregroundStyle(Theme.textPrimary)
                Text(today.day.ref)
                    .font(.system(.subheadline, design: .serif, weight: .semibold))
                    .foregroundStyle(Theme.goldText)
                Text(today.day.prompt)
                    .font(.akCallout)
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 12) {
                    PrimaryButton("Pray today’s reading", systemImage: "hands.and.sparkles.fill", height: 50) {
                        model.prayAdvent()
                    }
                    .accessibilityIdentifier("advent.pray")
                }
                Text(prayed == 0 ? "Pray once a day until Christmas Eve."
                                 : "You’ve prayed on \(prayed) of \(today.index + 1) Advent days so far.")
                    .font(.akFootnote)
                    .foregroundStyle(Theme.textTertiary)
                    .accessibilityIdentifier("advent.progress")
            }
            .akCard(highlighted: true)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("advent.card")
        }
    }
}
