import SwiftData
import SwiftUI

struct HomeView: View {
    @Environment(AppModel.self) private var model
    @Query(sort: \PrayerSession.completedAt, order: .reverse) private var sessions: [PrayerSession]
    @Query private var people: [Person]
    @State private var shareCard: ShareCardKind?
    @State private var showEmergency = false
    @State private var circleSummary: CircleSummary?

    var body: some View {
        ZStack {
            AppBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    GateStatusCard(onEmergency: { showEmergency = true })
                    HStack(alignment: .top, spacing: 14) {
                        prayNowCard
                        streakCard
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    quickRow
                    verseCard
                    todayStats
                    peoplePreview
                    circlePreview
                    challengePreview
                    Text(AppConstants.slogan)
                        .font(.system(.footnote, design: .serif, weight: .semibold))
                        .italic()
                        .foregroundStyle(Theme.textTertiary)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 6)
                }
                .padding(.horizontal, Spacing.page)
                .padding(.bottom, 32)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .sheet(item: $shareCard) { kind in
            ShareCardSheet(kind: kind).environment(model)
        }
        .sheet(isPresented: $showEmergency) {
            EmergencyPassSheet(app: nil)   // the pass opens every gated app, so don't name (and launch) just the first
                .environment(model)
                .presentationDetents([.medium])
        }
        .task(id: model.streak.current) { await loadCircle() }
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(Date().formatted(.dateTime.weekday(.wide).month(.wide).day()))
                    .akOverline(color: Theme.goldText)
                Text(greeting)
                    .font(.akLargeTitle)
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .accessibilityIdentifier("home.greeting")
            }
            Spacer()
            CircleIconButton(systemImage: "gearshape.fill", label: "Settings") { model.showSettings = true }
                .accessibilityIdentifier("home.settings")
        }
        .padding(.top, 12)
    }

    private var greeting: String {
        // The demo (screenshots) shows 9:41 in the status bar, so it greets the morning.
        let hour = model.options.isDemo ? 9 : Calendar.current.component(.hour, from: Date())
        let part: String
        switch hour {
        case 5..<12: part = "Good morning"
        case 12..<17: part = "Good afternoon"
        case 17..<22: part = "Good evening"
        default: part = "Peaceful night"
        }
        let name = model.settings.firstName.trimmingCharacters(in: .whitespaces)
        return name.isEmpty ? part : "\(part), \(name)"
    }

    // MARK: Pray now + streak

    private var prayNowCard: some View {
        Button {
            model.startPrayer(source: .manual)
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                PrayToScrollMark(glow: true)
                    .frame(height: 64)
                    .padding(.bottom, 14)
                Spacer(minLength: 0)
                Text("Pray now")
                    .font(.system(.title2, design: .serif, weight: .bold))
                    .foregroundStyle(Palette.midnight)
                Text(styleSummary)
                    .font(.akFootnote.weight(.semibold))
                    .foregroundStyle(Palette.midnight.opacity(0.7))
                    .lineLimit(2)
            }
            .padding(18)
            .frame(maxWidth: .infinity, minHeight: 190, alignment: .leading)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 26, style: .continuous).fill(Palette.goldButton)
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .fill(RadialGradient(colors: [Color.white.opacity(0.55), .clear], center: .topTrailing, startRadius: 0, endRadius: 160))
                    ArchShape()
                        .stroke(Palette.midnight.opacity(0.08), lineWidth: 18)
                        .frame(width: 120, height: 170)
                        .offset(x: 50, y: 30)
                        .clipped()
                }
                .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                .shadow(color: Palette.gold.opacity(0.35), radius: 18, y: 10)
            )
        }
        .buttonStyle(PressScaleStyle())
        .contextMenu {
            ForEach(UnlockStyle.allCases) { style in
                Button { model.startPrayer(style: style, source: .manual) } label: { Label(style.title, systemImage: style.symbol) }
            }
        }
        .accessibilityLabel("Pray now, \(styleSummary)")
        .accessibilityHint("Touch and hold to choose a prayer style")
        .accessibilityIdentifier("home.prayNow")
    }

    private var styleSummary: String {
        switch model.settings.unlockStyle {
        case .guided: return "Guided · \(SettingsFormat.length(model.settings.guidedSeconds))"
        case .quick: return "Quick · 30 sec"
        case .verse: return "Today's verse"
        case .forSomeone: return "For someone"
        }
    }

    private var streakCard: some View {
        Button {
            model.selectedTab = .progress
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                StreakFlame(streak: model.streak.current, lit: model.streak.current > 0 || model.streak.prayedToday, size: 64, showsNumber: false)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Spacer(minLength: 0)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(model.streak.current)")
                        .font(.akNumber(40))
                        .foregroundStyle(Theme.textPrimary)
                        .contentTransition(.numericText())
                    Text(model.streak.current == 1 ? "day" : "days")
                        .font(.akHeadline)
                        .foregroundStyle(Theme.textSecondary)
                }
                Text(streakLine)
                    .font(.akFootnote.weight(.semibold))
                    .foregroundStyle(model.streak.atRisk ? Theme.roseText : Theme.sageText)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(18)
            .frame(maxWidth: .infinity, minHeight: 190, alignment: .leading)
            .background(CardBackground(cornerRadius: 26))
        }
        .buttonStyle(PressScaleStyle())
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("home.streak")
    }

    private var streakLine: String {
        if model.streak.prayedToday { return "Today ✓ · \(model.streak.freezeAvailableThisWeek ? "grace day ready" : "grace used")" }
        if model.streak.current > 0 { return "Pray today to keep it" }
        return "Your first day starts now"
    }

    private var quickRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                quickChip("Tempted? Pray now", "shield.lefthalf.filled", tint: Theme.roseText) {
                    model.startPrayer(style: .quick, source: .manual, mood: .tempted)
                }
                quickChip("Pray for someone", "person.2.fill", tint: Theme.goldText) {
                    model.startPrayer(style: .forSomeone, source: .manual)
                }
                quickChip("Pray today's verse", "book.pages.fill", tint: Theme.sageText) {
                    model.startPrayer(style: .verse, source: .manual)
                }
                quickChip("Scroll the Word", "scroll.fill", tint: Theme.goldText) {
                    model.selectedTab = .word
                }
            }
            .padding(.horizontal, Spacing.page)
        }
        .padding(.horizontal, -Spacing.page)
    }

    private func quickChip(_ title: String, _ symbol: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: symbol).font(.system(size: 13, weight: .bold)).foregroundStyle(tint)
                Text(title).font(.akSubheadlineSemibold).foregroundStyle(Theme.textPrimary)
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 44)
            .background(Capsule().fill(Theme.surface))
            .overlay(Capsule().strokeBorder(Theme.stroke, lineWidth: 1))
        }
        .buttonStyle(PressScaleStyle())
    }

    // MARK: Verse

    private var verseCard: some View {
        let verse = model.verses.verse()
        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Today's verse").akOverline()
                Spacer()
                Chip(text: verse.themeTitle, tint: Theme.sageText)
            }
            Text(verse.text)
                .font(.akVerse)
                .foregroundStyle(Theme.textPrimary)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Text(verse.ref)
                    .font(.system(.subheadline, design: .serif, weight: .semibold))
                    .foregroundStyle(Theme.goldText)
                Spacer()
                Button {
                    model.startPrayer(style: .verse, source: .manual, verse: verse)
                } label: {
                    Label("Pray it", systemImage: "hands.and.sparkles.fill")
                        .font(.akSubheadlineSemibold)
                        .foregroundStyle(Theme.goldText)
                        .frame(minHeight: 44)
                }
                Button {
                    shareCard = .verse(verse)
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Theme.goldText)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("Share verse")
            }
        }
        .akCard()
    }

    // MARK: Stats

    private var todayStats: some View {
        let today = sessions.filter { Calendar.current.isDateInToday($0.completedAt) }
        let minutes = Int((today.reduce(0) { $0 + $1.durationSeconds } / 60).rounded())
        let instead = today.filter { $0.source == .gate }.count
        return VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Today")
            HStack(spacing: 12) {
                StatTile(value: "\(today.count)", label: today.count == 1 ? "prayer" : "prayers", systemImage: "hands.and.sparkles.fill")
                StatTile(value: "\(minutes)", label: "minutes with God", systemImage: "clock.fill", tint: Theme.sageText)
                StatTile(value: "\(instead)", label: "prayed instead of scrolling", systemImage: "iphone.slash", tint: Theme.roseText)
            }
        }
    }

    // MARK: People

    @ViewBuilder
    private var peoplePreview: some View {
        let ranked = Array(PeopleRanking.sorted(people).prefix(5))
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Pray for someone", actionTitle: people.isEmpty ? nil : "See all") { model.selectedTab = .people }
            if let next = ranked.first {
                HStack(spacing: 14) {
                    Avatar(name: next.name, emoji: next.emoji, colorIndex: next.colorIndex, size: 52)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(next.name).font(.akHeadline).foregroundStyle(Theme.textPrimary)
                        Text(PeopleRanking.lastPrayedText(next.lastPrayedAt))
                            .font(.akFootnote).foregroundStyle(Theme.textSecondary)
                        if let request = next.openRequests.first {
                            Text(request.text).font(.akFootnote).foregroundStyle(Theme.textTertiary).lineLimit(1)
                        }
                    }
                    Spacer(minLength: 8)
                    Button {
                        model.startPrayer(style: .forSomeone, source: .manual, personID: next.id)
                    } label: {
                        Text("Pray")
                            .font(.akSubheadlineSemibold)
                            .foregroundStyle(Palette.midnight)
                            .padding(.horizontal, 18)
                            .frame(minHeight: 40)
                            .background(Capsule().fill(Palette.goldButton))
                    }
                    .buttonStyle(PressScaleStyle())
                    .accessibilityLabel("Pray for \(next.firstName)")
                }
                if ranked.count > 1 {
                    HStack(spacing: -10) {
                        ForEach(ranked.dropFirst()) { person in
                            Avatar(name: person.name, emoji: person.emoji, colorIndex: person.colorIndex, size: 34)
                                .overlay(Circle().strokeBorder(Theme.background, lineWidth: 2))
                        }
                        Text("  + \(max(0, people.count - 1)) on your list")
                            .font(.akFootnote)
                            .foregroundStyle(Theme.textSecondary)
                    }
                    .accessibilityElement(children: .combine)
                }
            } else {
                Button { model.selectedTab = .people } label: {
                    HStack(spacing: 12) {
                        IconBadge(systemImage: "person.badge.plus")
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Who's on your heart?").font(.akHeadline).foregroundStyle(Theme.textPrimary)
                            Text("Add people to pray for. We'll remind you who's waited longest.")
                                .font(.akFootnote).foregroundStyle(Theme.textSecondary)
                        }
                        Spacer()
                    }
                }
                .buttonStyle(PressScaleStyle())
            }
        }
        .akCard()
    }

    // MARK: Circle

    struct CircleSummary: Equatable {
        var name: String
        var rank: Int
        var total: Int
        var top: [CircleMember]
    }

    @ViewBuilder
    private var circlePreview: some View {
        if let summary = circleSummary {
            Button { model.selectedTab = .together } label: {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("This week").akOverline()
                        Spacer()
                        Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(Theme.textTertiary)
                    }
                    Text(summary.rank == 1 ? "You're leading \(summary.name)" : "You're #\(summary.rank) in \(summary.name)")
                        .font(.akTitle3)
                        .foregroundStyle(Theme.textPrimary)
                        .multilineTextAlignment(.leading)
                    VStack(spacing: 8) {
                        ForEach(Array(summary.top.enumerated()), id: \.element.id) { index, member in
                            HStack(spacing: 10) {
                                Text("\(index + 1)")
                                    .font(.system(.subheadline, design: .serif, weight: .bold))
                                    .foregroundStyle(index == 0 ? Theme.goldText : Theme.textSecondary)
                                    .frame(width: 18)
                                Text(member.emoji)
                                Text(member.isMe ? "\(member.displayName) (you)" : member.displayName)
                                    .font(.akSubheadlineSemibold)
                                    .foregroundStyle(Theme.textPrimary)
                                Spacer()
                                Text("\(member.prayers(inWeek: CircleWeek.key())) prayers")
                                    .font(.akFootnote)
                                    .foregroundStyle(Theme.textSecondary)
                            }
                        }
                    }
                }
                .akCard()
            }
            .buttonStyle(PressScaleStyle())
        }
    }

    private func loadCircle() async {
        guard await model.circles.availability() == .available,
              let circle = try? await model.circles.myCircles().first,
              let members = try? await model.circles.members(code: circle.code) else {
            circleSummary = nil
            return
        }
        let week = CircleWeek.key()
        let blocked = CircleBlockList.blocked()
        let ranked = members.filter { !blocked.contains($0.id) && (!$0.isHidden || $0.isMe) }
            .sorted { $0.prayers(inWeek: week) > $1.prayers(inWeek: week) }
        let rank = (ranked.firstIndex { $0.isMe } ?? 0) + 1
        circleSummary = CircleSummary(name: circle.name, rank: rank, total: ranked.count, top: Array(ranked.prefix(3)))
    }

    // MARK: Challenge

    @ViewBuilder
    private var challengePreview: some View {
        if let active = model.settings.activeChallenges.first, let definition = model.content.challenge(id: active.id) {
            let progress = model.progress(for: definition, active: active)
            Button { model.selectedTab = .together } label: {
                HStack(spacing: 16) {
                    ZStack {
                        ProgressRing(progress: progress.fraction, lineWidth: 7)
                            .frame(width: 58, height: 58)
                        Image(systemName: definition.symbol).foregroundStyle(Theme.goldIcon)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Challenge · Day \(min(progress.dayIndex, definition.days)) of \(definition.days)").akOverline()
                        Text(definition.title).font(.akHeadline).foregroundStyle(Theme.textPrimary)
                        if let tip = definition.tip(forDay: progress.dayIndex) {
                            Text(tip).font(.akFootnote).foregroundStyle(Theme.textSecondary).lineLimit(2)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .akCard()
            }
            .buttonStyle(PressScaleStyle())
        }
    }
}

enum SettingsFormat {
    static func length(_ seconds: Int) -> String {
        seconds < 60 ? "\(seconds) sec" : "\(seconds / 60) min"
    }
}
