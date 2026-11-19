import SwiftUI

/// The top of Progress: the last 7 days against the 7 before, what you reach for, and one useful idea.
struct WeekCard: View {
    @Environment(AppModel.self) private var model
    let report: WeekReport
    let onShare: () -> Void

    var body: some View {
        let insight = model.weekInsight(for: report)
        VStack(alignment: .leading, spacing: 16) {
            header
            if report.isEmpty {
                emptyBody(insight)
            } else {
                headline
                dayDots
                details
                insightBox(insight)
            }
        }
        .akCard(highlighted: true)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("stats.week")
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Your week").akOverline()
                Text("The last 7 days")
                    .font(.akFootnote)
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer()
            if !report.isEmpty {
                Button(action: onShare) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Theme.goldText)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("Share your week")
                .accessibilityIdentifier("stats.week.share")
            }
        }
    }

    // MARK: Numbers

    private var headline: some View {
        HStack(alignment: .top, spacing: 10) {
            metric(value: "\(report.prayers.now)", label: report.prayers.now == 1 ? "prayer" : "prayers", delta: report.prayers.delta,
                   unit: "prayers")
            metric(value: "\(report.minutes.now)", label: "minutes with God", delta: report.minutes.delta, unit: "minutes")
            metric(value: "\(report.daysPrayed)/7", label: "days prayed", delta: nil, unit: "")
        }
    }

    private func metric(value: String, label: String, delta: Int?, unit: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(value)
                    .font(.system(.title, design: .serif, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                if let delta, delta != 0 { deltaBadge(delta) }
            }
            Text(label)
                .font(.akFootnote)
                .foregroundStyle(Theme.textSecondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(value) \(label)" + (delta.map { deltaSpoken($0, unit: unit) } ?? ""))
    }

    /// ↑ in sage; ↓ stays quiet (a gray arrow, no red): a slower week isn't a failure.
    private func deltaBadge(_ delta: Int) -> some View {
        Text(delta > 0 ? "↑\(delta)" : "↓\(-delta)")
            .font(.akCaption.weight(.bold))
            .foregroundStyle(delta > 0 ? Theme.sageText : Theme.textTertiary)
    }

    private func deltaSpoken(_ delta: Int, unit: String) -> String {
        if delta == 0 { return ", the same as the week before" }
        return delta > 0 ? ", \(delta) more \(unit) than the week before" : ", \(-delta) fewer \(unit) than the week before"
    }

    private var dayDots: some View {
        let calendar = Calendar.current
        let letters = calendar.veryShortStandaloneWeekdaySymbols
        return HStack(spacing: 0) {
            ForEach(Array(report.days.enumerated()), id: \.offset) { index, day in
                let prayed = report.prayedOn.indices.contains(index) && report.prayedOn[index]
                let weekday = calendar.component(.weekday, from: day.noonDate(in: calendar))
                VStack(spacing: 6) {
                    ZStack {
                        Circle()
                            .fill(prayed ? AnyShapeStyle(Palette.goldButton) : AnyShapeStyle(Theme.stroke.opacity(0.6)))
                        if prayed {
                            Image(systemName: "checkmark").font(.system(size: 11, weight: .bold)).foregroundStyle(Palette.midnight)
                        }
                    }
                    .overlay(Circle().strokeBorder(index == report.days.count - 1 ? Theme.goldText : .clear, lineWidth: 1.5))
                    .frame(width: 28, height: 28)
                    Text(letters.indices.contains(weekday - 1) ? letters[weekday - 1] : "")
                        .font(.akCaption)
                        .foregroundStyle(Theme.textTertiary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Prayed on \(report.daysPrayed) of the last 7 days")
    }

    // MARK: Details

    @ViewBuilder
    private var details: some View {
        let rows = detailRows
        if !rows.isEmpty {
            VStack(spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                    if index > 0 { Divider().overlay(Theme.stroke) }
                    HStack(spacing: 12) {
                        Image(systemName: row.symbol)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(row.tint)
                            .frame(width: 30, height: 30)
                            .background(Circle().fill(row.tint.opacity(0.14)))
                        Text(row.title)
                            .font(.akSubheadline)
                            .foregroundStyle(Theme.textSecondary)
                        Spacer(minLength: 8)
                        Text(row.value)
                            .font(.akSubheadlineSemibold)
                            .foregroundStyle(Theme.textPrimary)
                            .multilineTextAlignment(.trailing)
                    }
                    .padding(.vertical, 8)
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }

    private struct Row {
        var symbol: String
        var tint: Color
        var title: String
        var value: String
    }

    private var detailRows: [Row] {
        var rows: [Row] = []
        let gateInUse = !model.settings.gatedApps.isEmpty
        if report.putDown.now > 0 || gateInUse {
            let delta = report.putDown.delta
            rows.append(Row(symbol: "hand.raised.fill", tint: Theme.sageText, title: "Chose not to scroll",
                            value: "\(report.putDown.now)" + (delta > 0 ? "  ↑\(delta)" : "")))
        }
        if report.prayedFirst.now > 0 || gateInUse {
            rows.append(Row(symbol: "scroll.fill", tint: Theme.goldIcon, title: "Prayed first", value: "\(report.prayedFirst.now)"))
        }
        if let top = report.topApp {
            rows.append(Row(symbol: "arrow.up.forward.app.fill", tint: Theme.roseText, title: "Reached for most",
                            value: "\(model.appName(for: top.key)) · \(top.count)×"))
        }
        if let hour = report.topHourValue {
            rows.append(Row(symbol: "clock.fill", tint: Theme.roseText, title: "Most-tempted hour",
                            value: "around \(WeekInsightEngine.timeText(hour: hour, calendar: .current))"))
        }
        if let mood = report.topMood {
            rows.append(Row(symbol: mood.symbol, tint: Theme.goldIcon, title: "Most-felt", value: mood.title))
        }
        if report.peoplePrayedFor > 0 {
            rows.append(Row(symbol: "person.2.fill", tint: Theme.goldIcon, title: "People prayed for", value: "\(report.peoplePrayedFor)"))
        }
        if report.answered > 0 {
            rows.append(Row(symbol: "checkmark.seal.fill", tint: Theme.sageText, title: "Prayers answered", value: "\(report.answered)"))
        }
        if report.versesRead > 0 || report.versesSaved > 0 {
            let saved = report.versesSaved > 0 ? " · \(report.versesSaved) saved" : ""
            rows.append(Row(symbol: "book.fill", tint: Theme.sageText, title: "Verses read", value: "\(report.versesRead)\(saved)"))
        }
        if report.storiesWatched > 0 {
            rows.append(Row(symbol: "play.rectangle.fill", tint: Theme.goldIcon, title: "Bible Stories watched", value: "\(report.storiesWatched)"))
        }
        if report.emergencyPasses > 0 {
            rows.append(Row(symbol: "bolt.fill", tint: Theme.textTertiary, title: "Emergency passes", value: "\(report.emergencyPasses)"))
        }
        return rows
    }

    // MARK: Insight

    private func insightBox(_ insight: WeekInsight) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.goldIcon)
                    .padding(.top, 2)
                Text(insight.text)
                    .font(.akCallout)
                    .foregroundStyle(Theme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("stats.week.insight")
            }
            if let title = insight.actionTitle, let action = insight.action {
                Button {
                    Haptics.tap()
                    model.perform(action)
                } label: {
                    Text(title)
                        .font(.akSubheadlineSemibold)
                        .foregroundStyle(Palette.midnight)
                        .padding(.horizontal, 18)
                        .frame(minHeight: 44)
                        .background(Capsule().fill(Palette.goldButton))
                }
                .buttonStyle(PressScaleStyle())
                .accessibilityIdentifier("stats.week.action")
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Theme.goldText.opacity(0.08)))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Theme.goldText.opacity(0.2), lineWidth: 1))
    }

    // MARK: Empty

    private func emptyBody(_ insight: WeekInsight) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your week with God shows up here")
                .font(.akTitle3)
                .foregroundStyle(Theme.textPrimary)
            Text("Pray, put the phone down, read a verse. Each Sunday you'll see what changed, plus one idea for the week ahead.")
                .font(.akFootnote)
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            if let title = insight.actionTitle, let action = insight.action {
                Button {
                    Haptics.tap()
                    model.perform(action)
                } label: {
                    Label(title, systemImage: "hands.and.sparkles.fill")
                        .font(.akSubheadlineSemibold)
                        .foregroundStyle(Palette.midnight)
                        .padding(.horizontal, 18)
                        .frame(minHeight: 44)
                        .background(Capsule().fill(Palette.goldButton))
                }
                .buttonStyle(PressScaleStyle())
                .accessibilityIdentifier("stats.week.action")
            }
        }
    }
}
