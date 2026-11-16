import SwiftUI
import WidgetKit

@main
struct PrayToScrollWidgets: WidgetBundle {
    var body: some Widget {
        StreakWidget()
        VerseWidget()
        PrayNowWidget()
    }
}

// MARK: - Timeline

struct PrayEntry: TimelineEntry {
    let date: Date
    let streak: StreakSummary
    let verse: Verse
    let unlockedUntil: Date?
    let firstName: String

    static let placeholder = PrayEntry(date: Date(),
                                       streak: StreakSummary(current: 12, longest: 21, prayedToday: true, totalDaysPrayed: 64,
                                                             freezeAvailableThisWeek: true, atRisk: false, frozenDays: []),
                                       verse: .fallback, unlockedUntil: nil, firstName: "")
}

struct PrayProvider: TimelineProvider {
    func placeholder(in context: Context) -> PrayEntry { .placeholder }

    func getSnapshot(in context: Context, completion: @escaping (PrayEntry) -> Void) {
        completion(context.isPreview ? .placeholder : entry(at: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PrayEntry>) -> Void) {
        let now = Date()
        let calendar = Calendar.current
        var entries = [entry(at: now)]
        // Refresh at 8 PM (streak at risk look) and just after midnight (new day, new verse).
        if let evening = calendar.date(bySettingHour: 20, minute: 0, second: 0, of: now), evening > now {
            entries.append(entry(at: evening))
        }
        let midnight = calendar.startOfDay(for: now.addingTimeInterval(86_400)).addingTimeInterval(60)
        entries.append(entry(at: midnight))
        completion(Timeline(entries: entries, policy: .after(midnight)))
    }

    private func entry(at date: Date) -> PrayEntry {
        let store = SharedStore.shared
        VerseProvider.shared.translation = store.settings.translation
        return PrayEntry(date: date, streak: store.streakSummary(now: date), verse: VerseProvider.shared.verse(for: date),
                         unlockedUntil: store.unlockedUntil, firstName: store.settings.firstName)
    }
}

// MARK: - Streak (small + lock screen)

struct StreakWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: AppConstants.widgetKindStreak, provider: PrayProvider()) { entry in
            StreakWidgetView(entry: entry)
                .widgetURL(AppLinks.statsDeepLink)
        }
        .configurationDisplayName("Prayer streak")
        .description("Your streak, and whether today's prayer is done.")
        .supportedFamilies([.systemSmall, .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

struct StreakWidgetView: View {
    let entry: PrayEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 0) {
                    Image(systemName: entry.streak.prayedToday ? "flame.fill" : "flame")
                        .font(.system(size: 14, weight: .semibold))
                    Text("\(entry.streak.current)")
                        .font(.system(size: 20, weight: .bold, design: .serif))
                        .minimumScaleFactor(0.6)
                }
            }
            .containerBackground(for: .widget) { Color.clear }
            .accessibilityLabel("\(entry.streak.current) day prayer streak")
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                Label("\(entry.streak.current)-day streak", systemImage: "flame.fill")
                    .font(.headline)
                Text(entry.streak.prayedToday ? "Today's prayer is done" : "Pray today to keep it")
                    .font(.caption)
            }
            .containerBackground(for: .widget) { Color.clear }
        case .accessoryInline:
            Label("\(entry.streak.current) days · \(entry.streak.prayedToday ? "prayed" : "pray today")", systemImage: "flame.fill")
                .containerBackground(for: .widget) { Color.clear }
        default:
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    WidgetFlame(lit: entry.streak.prayedToday)
                        .frame(width: 34, height: 40)
                    Spacer()
                    PrayToScrollMark(glow: false).frame(width: 14, height: 20).opacity(0.8)
                }
                Spacer(minLength: 0)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(entry.streak.current)")
                        .font(.system(size: 44, weight: .bold, design: .serif))
                        .foregroundStyle(Palette.cream)
                        .minimumScaleFactor(0.6)
                    Text(entry.streak.current == 1 ? "day" : "days")
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .foregroundStyle(Palette.cream.opacity(0.7))
                }
                Text(entry.streak.prayedToday ? "Prayed today ✓" : (entry.streak.current > 0 ? "Pray to keep it" : "Start today"))
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .foregroundStyle(entry.streak.prayedToday ? Palette.sage : Palette.warmGold)
            }
            .containerBackground(for: .widget) { WidgetBackground() }
            .accessibilityElement(children: .combine)
        }
    }
}

// MARK: - Verse (medium)

struct VerseWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: AppConstants.widgetKindVerse, provider: PrayProvider()) { entry in
            VerseWidgetView(entry: entry)
                .widgetURL(URL(string: "\(AppConstants.urlScheme)://word"))
        }
        .configurationDisplayName("Today's verse")
        .description("A new verse every day, ready to pray.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

struct VerseWidgetView: View {
    let entry: PrayEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("TODAY'S VERSE")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .tracking(1.2)
                    .foregroundStyle(Palette.warmGold)
                Spacer()
                PrayToScrollMark(glow: false).frame(width: 12, height: 17).opacity(0.8)
            }
            Text(entry.verse.displayText)
                .font(.system(family == .systemLarge ? .title3 : .callout, design: .serif))
                .foregroundStyle(Palette.cream)
                .minimumScaleFactor(0.6)
                .lineLimit(family == .systemLarge ? 10 : 4)
            Spacer(minLength: 0)
            HStack {
                Text(entry.verse.ref)
                    .font(.system(.footnote, design: .serif, weight: .semibold))
                    .foregroundStyle(Palette.warmGold)
                Spacer()
                Link(destination: AppLinks.prayDeepLink) {
                    Label("Pray it", systemImage: "hands.and.sparkles.fill")
                        .font(.system(.caption, design: .rounded, weight: .bold))
                        .foregroundStyle(Palette.midnight)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(Palette.goldButton))
                }
            }
        }
        .containerBackground(for: .widget) { WidgetBackground() }
    }
}

// MARK: - Pray now

struct PrayNowWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: AppConstants.widgetKindPrayNow, provider: PrayProvider()) { entry in
            PrayNowWidgetView(entry: entry)
                .widgetURL(AppLinks.prayDeepLink)
        }
        .configurationDisplayName("Pray now")
        .description("One tap to a quiet prayer.")
        .supportedFamilies([.systemSmall, .accessoryCircular])
    }
}

struct PrayNowWidgetView: View {
    let entry: PrayEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        if family == .accessoryCircular {
            ZStack {
                AccessoryWidgetBackground()
                Image(systemName: "hands.and.sparkles.fill").font(.system(size: 20, weight: .semibold))
            }
            .containerBackground(for: .widget) { Color.clear }
            .accessibilityLabel("Pray now")
        } else {
            VStack(spacing: 10) {
                ZStack {
                    Circle().fill(RadialGradient(colors: [Palette.gold.opacity(0.45), .clear], center: .center, startRadius: 0, endRadius: 44))
                        .frame(width: 88, height: 88)
                    PrayToScrollMark(glow: true).frame(width: 34, height: 48)
                }
                Text("Pray now")
                    .font(.system(.headline, design: .serif, weight: .bold))
                    .foregroundStyle(Palette.cream)
                Text(AppConstants.slogan)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(Palette.cream.opacity(0.6))
            }
            .containerBackground(for: .widget) { WidgetBackground() }
        }
    }
}

// MARK: - Shared pieces

struct WidgetBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: 0x15223A), Palette.midnight, Palette.midnightDeep], startPoint: .top, endPoint: .bottom)
            RadialGradient(colors: [Palette.gold.opacity(0.22), .clear], center: .top, startRadius: 0, endRadius: 160)
        }
    }
}

struct WidgetFlame: View {
    var lit: Bool
    var body: some View {
        Image(systemName: lit ? "flame.fill" : "flame")
            .resizable()
            .scaledToFit()
            .foregroundStyle(lit ? AnyShapeStyle(Palette.flameGradient) : AnyShapeStyle(Color.gray))
    }
}
