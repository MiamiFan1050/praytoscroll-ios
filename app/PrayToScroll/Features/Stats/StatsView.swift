import SwiftData
import SwiftUI

/// Progress: streak, grace day, heatmap, milestones, totals, time reclaimed, and the journal.
struct StatsView: View {
    @Environment(AppModel.self) private var model
    @Query(sort: \PrayerSession.completedAt) private var sessions: [PrayerSession]
    @Query private var journal: [JournalEntry]
    @State private var shareCard: ShareCardKind?

    var body: some View {
        @Bindable var model = model
        ZStack {
            AppBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    streakHero
                    graceCard
                    heatmapCard
                    journalRow
                    totals
                    reclaimedCard
                    milestones
                }
                .padding(.horizontal, Spacing.page)
                .padding(.bottom, 36)
            }
        }
        .navigationTitle("Progress")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { shareCard = .streak } label: { Image(systemName: "square.and.arrow.up") }
                    .tint(Theme.goldIcon)
                    .accessibilityLabel("Share your streak")
            }
        }
        .navigationDestination(isPresented: $model.openJournal) { JournalView() }
        .sheet(item: $shareCard) { kind in ShareCardSheet(kind: kind).environment(model) }
        .onAppear { model.refreshStreak() }
    }

    // MARK: Streak

    private var streakHero: some View {
        let streak = model.streak
        return HStack(spacing: 18) {
            StreakFlame(streak: streak.current, lit: streak.current > 0 || streak.prayedToday, size: 96, showsNumber: false)
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(streak.current)")
                        .font(.akNumber(56))
                        .foregroundStyle(Theme.textPrimary)
                        .contentTransition(.numericText())
                        .accessibilityIdentifier("stats.streak")
                    Text(streak.current == 1 ? "day" : "days")
                        .font(.akTitle3)
                        .foregroundStyle(Theme.textSecondary)
                }
                Text(streak.prayedToday ? "Today's prayer is done." : (streak.current > 0 ? "Pray today to keep it going." : "Your next streak starts with one prayer."))
                    .font(.akFootnote.weight(.semibold))
                    .foregroundStyle(streak.prayedToday ? Theme.sageText : Theme.goldText)
                Text("Longest: \(streak.longest) \(streak.longest == 1 ? "day" : "days")")
                    .font(.akFootnote)
                    .foregroundStyle(Theme.textSecondary)
                if let next = MilestoneEngine.next(after: streak.current) {
                    Text("\(next - streak.current) to \(MilestoneEngine.title(for: next))")
                        .font(.akFootnote)
                        .foregroundStyle(Theme.textTertiary)
                }
            }
            Spacer(minLength: 0)
        }
        .akCard(highlighted: true)
        .accessibilityElement(children: .combine)
    }

    private var graceCard: some View {
        let streak = model.streak
        let usedDay = streak.frozenDays.filter { WeekID($0, calendar: .current) == WeekID(DayKey(Date(), calendar: .current), calendar: .current) }.first
        return HStack(spacing: 14) {
            ZStack {
                Circle().fill(Color(hex: 0x8FB8E8).opacity(0.18)).frame(width: 50, height: 50)
                Image(systemName: "snowflake").font(.title3.weight(.semibold)).foregroundStyle(Color(hex: 0x8FB8E8))
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(streak.freezeAvailableThisWeek ? "Grace day ready" : "Grace day used this week")
                    .font(.akHeadline).foregroundStyle(Theme.textPrimary)
                Text(streak.freezeAvailableThisWeek
                     ? "Miss a day this week and your streak waits for you. Automatically."
                     : "It covered \(usedDay.map { $0.startDate(in: .current).formatted(.dateTime.weekday(.wide)) } ?? "a missed day"). A new one comes Sunday.")
                    .font(.akFootnote).foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Grace is free. We'll never sell streak freezes.")
                    .font(.akCaption).foregroundStyle(Theme.textTertiary)
            }
            Spacer(minLength: 0)
        }
        .akCard()
    }

    // MARK: Heatmap

    private var heatmapCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Last 16 weeks").font(.akHeadline).foregroundStyle(Theme.textPrimary)
                Spacer()
                Text("\(model.streak.totalDaysPrayed) days prayed").font(.akFootnote).foregroundStyle(Theme.textSecondary)
            }
            PrayerHeatmap(prayed: model.prayedDays, frozen: model.streak.frozenDays, counts: dayCounts)
            HStack(spacing: 14) {
                legend(color: Palette.gold, "Prayed")
                legend(color: Color(hex: 0x8FB8E8), "Grace day")
                legend(color: Theme.stroke, "Not yet")
            }
        }
        .akCard()
    }

    private func legend(color: Color, _ text: String) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 3).fill(color).frame(width: 12, height: 12)
            Text(text).font(.akCaption).foregroundStyle(Theme.textSecondary)
        }
    }

    private var dayCounts: [DayKey: Int] {
        var counts: [DayKey: Int] = [:]
        for session in sessions { counts[DayKey(session.completedAt, calendar: .current), default: 0] += 1 }
        return counts
    }

    // MARK: Journal

    private var journalRow: some View {
        Button { model.openJournal = true } label: {
            HStack(spacing: 14) {
                IconBadge(systemImage: "book.closed.fill", size: 44)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Prayer journal").font(.akHeadline).foregroundStyle(Theme.textPrimary)
                    Text(journal.isEmpty ? "Write what's on your heart" : "\(journal.count) \(journal.count == 1 ? "entry" : "entries")")
                        .font(.akFootnote).foregroundStyle(Theme.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(Theme.textTertiary)
            }
            .akCard()
        }
        .buttonStyle(PressScaleStyle())
        .accessibilityIdentifier("stats.journal")
    }

    // MARK: Totals

    private var totals: some View {
        let minutes = Int((sessions.reduce(0) { $0 + $1.durationSeconds } / 60).rounded())
        let people = Set(sessions.map { $0.personName.lowercased() }.filter { !$0.isEmpty }).count
        return VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "All time")
            HStack(spacing: 12) {
                StatTile(value: "\(sessions.count)", label: "prayers", systemImage: "hands.and.sparkles.fill")
                StatTile(value: minutes >= 120 ? "\(minutes / 60)h" : "\(minutes)m", label: "with God", systemImage: "clock.fill", tint: Theme.sageText)
            }
            HStack(spacing: 12) {
                StatTile(value: "\(model.gatesHonoured)", label: "times you prayed instead of scrolling", systemImage: "iphone.slash", tint: Theme.roseText)
                StatTile(value: "\(people)", label: people == 1 ? "person prayed for" : "people prayed for", systemImage: "person.2.fill")
            }
        }
    }

    private var reclaimedCard: some View {
        let instead = model.gatesHonoured
        let hours = Double(instead) * AppConstants.averageScrollSessionMinutes / 60
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("About \(hours < 10 ? String(format: "%.1f", hours) : String(Int(hours.rounded()))) hours")
                    .font(.system(.title, design: .serif, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
            }
            Text("given back to God instead of the feed.")
                .font(.akCallout).foregroundStyle(Theme.textSecondary)
            Text("An estimate: \(instead) prayed-instead moments × the average \(Int(AppConstants.averageScrollSessionMinutes))-minute scroll. Emergency passes used: \(model.emergencyUses).")
                .font(.akCaption).foregroundStyle(Theme.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
            Button { shareCard = .prayedInstead } label: {
                Label("Share \"I prayed instead\"", systemImage: "square.and.arrow.up")
                    .font(.akSubheadlineSemibold)
                    .foregroundStyle(Theme.goldText)
                    .frame(minHeight: 44)
            }
        }
        .akCard()
    }

    // MARK: Milestones

    private var milestones: some View {
        let awarded = Set(model.settings.awardedMilestones)
        return VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Milestones")
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 18) {
                ForEach(MilestoneEngine.milestones, id: \.self) { milestone in
                    let earned = awarded.contains(milestone)
                    Button {
                        if earned { shareCard = .milestone(milestone) }
                    } label: {
                        VStack(spacing: 8) {
                            BadgeView(milestone: milestone, earned: earned, size: 62)
                            Text(MilestoneEngine.title(for: milestone))
                                .font(.akCaption)
                                .foregroundStyle(earned ? Theme.textPrimary : Theme.textTertiary)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                                .minimumScaleFactor(0.8)
                        }
                    }
                    .buttonStyle(PressScaleStyle())
                    .disabled(!earned)
                }
            }
        }
        .akCard()
    }
}

/// GitHub-style grid: columns are weeks (oldest left), rows are weekdays.
struct PrayerHeatmap: View {
    let prayed: Set<DayKey>
    let frozen: Set<DayKey>
    let counts: [DayKey: Int]
    var weeks: Int = 16

    var body: some View {
        let calendar = Calendar.current
        let today = DayKey(Date(), calendar: calendar)
        let weekday = calendar.component(.weekday, from: today.startDate(in: calendar))
        let offsetInWeek = (weekday - calendar.firstWeekday + 7) % 7
        let startOfThisWeek = today.adding(days: -offsetInWeek, calendar: calendar)
        let firstDay = startOfThisWeek.adding(days: -7 * (weeks - 1), calendar: calendar)
        GeometryReader { geo in
            let gap: CGFloat = 4
            let side = min((geo.size.width - gap * CGFloat(weeks - 1)) / CGFloat(weeks), 18)
            HStack(alignment: .top, spacing: gap) {
                ForEach(0..<weeks, id: \.self) { week in
                    VStack(spacing: gap) {
                        ForEach(0..<7, id: \.self) { day in
                            let key = firstDay.adding(days: week * 7 + day, calendar: calendar)
                            cell(key, today: today)
                                .frame(width: side, height: side)
                        }
                    }
                }
            }
        }
        .frame(height: 7 * 18 + 6 * 4)
        .accessibilityElement()
        .accessibilityLabel("Prayer calendar: \(prayed.count) days prayed")
    }

    @ViewBuilder
    private func cell(_ key: DayKey, today: DayKey) -> some View {
        let shape = RoundedRectangle(cornerRadius: 4, style: .continuous)
        if key > today {
            shape.fill(Color.clear)
        } else if prayed.contains(key) {
            let count = counts[key] ?? 1
            shape.fill(Palette.gold.opacity(count >= 3 ? 1 : (count == 2 ? 0.8 : 0.6)))
                .overlay(shape.strokeBorder(key == today ? Palette.cream : .clear, lineWidth: 1.5))
        } else if frozen.contains(key) {
            shape.fill(Color(hex: 0x8FB8E8).opacity(0.75))
        } else {
            shape.fill(Theme.stroke)
                .overlay(shape.strokeBorder(key == today ? Palette.gold : .clear, lineWidth: 1.5))
        }
    }
}
