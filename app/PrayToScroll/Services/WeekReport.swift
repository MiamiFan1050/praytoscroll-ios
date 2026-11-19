import Foundation

/// A prayer as "Your week" sees it, so the week math runs (and is tested) without SwiftData.
struct WeekSessionFact: Equatable, Sendable {
    var completedAt: Date
    var durationSeconds: Double
    var personName: String = ""
    var isGate: Bool = false
    /// False for an "I prayed offline" day: it keeps the streak but isn't a prayer we timed.
    var isTimedPrayer: Bool = true
}

/// "Your week": the last 7 days against the 7 before, from the prayer log and the local activity log.
struct WeekReport: Equatable, Sendable {
    struct Pair: Equatable, Sendable {
        var now: Int
        var before: Int
        var delta: Int { now - before }
    }

    struct Top: Equatable, Sendable {
        var key: String
        var count: Int
    }

    var window: DateInterval
    var days: [DayKey]
    /// Prayed (or marked prayed offline) on each of `days`, oldest first.
    var prayedOn: [Bool]
    var prayers: Pair
    var minutes: Pair
    var peoplePrayedFor: Int
    var answered: Int
    var versesRead: Int
    var versesSaved: Int
    var storiesWatched: Int
    var nightPrayers: Int
    var reaches: Pair
    var prayedFirst: Pair
    var putDown: Pair
    var emergencyPasses: Int
    /// The app reached for most (catalog id), from this week's gate reaches.
    var topApp: Top?
    /// The hour (0–23, the calendar's time zone) with the most reaches.
    var topHour: Top?
    /// The mood chip picked most this week.
    var topMood: PrayerMood?
    var topMoodCount: Int
    var streak: Int

    var daysPrayed: Int { prayedOn.filter { $0 }.count }

    /// A brand-new (or long-quiet) user: nothing to show for either week.
    var isEmpty: Bool {
        prayers.now == 0 && prayers.before == 0 && reaches.now == 0 && putDown.now == 0 && versesRead == 0
            && storiesWatched == 0 && daysPrayed == 0
    }

    /// Reaches needed before we name a pattern (an hour or an app).
    static let patternMinimum = 3

    static func make(now: Date, calendar: Calendar, sessions: [WeekSessionFact], answeredAt: [Date] = [],
                     savedAt: [Date] = [], readByDay: [String: Int] = [:], events: [ActivityEvent] = [],
                     streak: Int = 0) -> WeekReport {
        let current = WeekWindow.current(now: now, calendar: calendar)
        let previous = WeekWindow.previous(now: now, calendar: calendar)
        let days = WeekWindow.days(now: now, calendar: calendar)
        func inside(_ date: Date, _ window: DateInterval) -> Bool { date >= window.start && date < window.end }

        let thisWeek = sessions.filter { inside($0.completedAt, current) }
        let lastWeek = sessions.filter { inside($0.completedAt, previous) }
        let timedNow = thisWeek.filter(\.isTimedPrayer)
        let timedBefore = lastWeek.filter(\.isTimedPrayer)
        let prayedDays = Set(thisWeek.map { DayKey($0.completedAt, calendar: calendar) })
        func minutes(_ list: [WeekSessionFact]) -> Int { Int((list.reduce(0) { $0 + $1.durationSeconds } / 60).rounded()) }
        let people = Set(timedNow.map { $0.personName.trimmingCharacters(in: .whitespaces).lowercased() }.filter { !$0.isEmpty })

        func logged(_ kind: ActivityEvent.Kind, _ window: DateInterval) -> [ActivityEvent] {
            events.filter { $0.kind == kind && inside($0.at, window) }
        }
        let reachesNow = logged(.reach, current)
        // A gate prayer is "prayed first" whether the log has it (new) or only the session does (older prayers).
        let firstNow = max(logged(.prayedFirst, current).count, timedNow.filter(\.isGate).count)
        let firstBefore = max(logged(.prayedFirst, previous).count, timedBefore.filter(\.isGate).count)

        let appCounts = Dictionary(grouping: reachesNow.compactMap { $0.app }.filter { $0 != GateEngine.anyAppID }, by: { $0 })
            .mapValues(\.count)
        let hourCounts = Dictionary(grouping: reachesNow.map { calendar.component(.hour, from: $0.at) }, by: { $0 }).mapValues(\.count)
        let moodCounts = Dictionary(grouping: logged(.mood, current).compactMap { $0.detail.flatMap(PrayerMood.init(rawValue:)) },
                                    by: { $0 }).mapValues(\.count)

        // Ties go to the earliest hour / the first app or mood alphabetically, so the answer never flickers.
        let topApp = appCounts.max { ($0.value, $1.key) < ($1.value, $0.key) }
        let topHour = hourCounts.max { ($0.value, $1.key) < ($1.value, $0.key) }
        let topMood = moodCounts.max { ($0.value, $1.key.rawValue) < ($1.value, $0.key.rawValue) }

        return WeekReport(
            window: current,
            days: days,
            prayedOn: days.map { prayedDays.contains($0) },
            prayers: Pair(now: timedNow.count, before: timedBefore.count),
            minutes: Pair(now: minutes(timedNow), before: minutes(timedBefore)),
            peoplePrayedFor: people.count,
            answered: answeredAt.filter { inside($0, current) }.count,
            versesRead: days.reduce(0) { $0 + (readByDay[$1.string] ?? 0) },
            versesSaved: savedAt.filter { inside($0, current) }.count,
            storiesWatched: logged(.story, current).count,
            nightPrayers: logged(.nightPrayer, current).count,
            reaches: Pair(now: reachesNow.count, before: logged(.reach, previous).count),
            prayedFirst: Pair(now: firstNow, before: firstBefore),
            putDown: Pair(now: logged(.putDown, current).count, before: logged(.putDown, previous).count),
            emergencyPasses: logged(.emergency, current).count,
            topApp: topApp.flatMap { $0.value >= patternMinimum ? Top(key: $0.key, count: $0.value) : nil },
            topHour: topHour.flatMap { $0.value >= patternMinimum ? Top(key: String($0.key), count: $0.value) : nil },
            topMood: topMood?.key,
            topMoodCount: topMood?.value ?? 0,
            streak: streak
        )
    }

    var topHourValue: Int? { topHour.flatMap { Int($0.key) } }
}

/// The one useful sentence under "Your week", with a one-tap action.
struct WeekInsight: Equatable, Sendable {
    enum Action: Equatable, Sendable {
        /// Turn on the "before you scroll" reminder at this time (the existing ReminderService schedules it).
        case remind(hour: Int, minute: Int, appID: String)
        case prayTopic(PrayerTopic)
        case prayTempted
        case nightPrayer
        case prayNow
    }

    var text: String
    var actionTitle: String?
    var action: Action?
}

enum WeekInsightEngine {
    /// 15 minutes before the tempted hour starts (10 PM → 9:45 PM; midnight → 11:45 PM).
    static func reminderTime(beforeHour hour: Int) -> (hour: Int, minute: Int) {
        ((hour + 23) % 24, 45)
    }

    /// "10 PM" / "9:45 PM" in the calendar's locale and time zone.
    static func timeText(hour: Int, minute: Int? = nil, calendar: Calendar) -> String {
        let formatter = DateFormatter()
        formatter.locale = calendar.locale ?? .current
        formatter.timeZone = calendar.timeZone
        formatter.calendar = calendar
        formatter.setLocalizedDateFormatFromTemplate(minute == nil ? "j" : "jmm")
        var parts = DateComponents()
        parts.year = 2026
        parts.month = 1
        parts.day = 5
        parts.hour = hour
        parts.minute = minute ?? 0
        guard let date = calendar.date(from: parts) else { return "\(hour):00" }
        return formatter.string(from: date)
    }

    /// `nudge`: the reminder already set from an earlier insight (nil when it's off).
    static func make(report: WeekReport, appName: (String) -> String, calendar: Calendar,
                     nudge: (hour: Int, minute: Int)? = nil) -> WeekInsight {
        if report.isEmpty {
            return WeekInsight(text: "Your week starts with one prayer. Come back Sunday to see what changed.",
                               actionTitle: "Pray now", action: .prayNow)
        }

        // 1. The tempted hour: the most useful thing we can offer is a prayer just before it.
        if let hour = report.topHourValue {
            let time = reminderTime(beforeHour: hour)
            let already = nudge.map { $0.hour == time.hour && $0.minute == time.minute } ?? false
            if !already {
                let who = report.topApp.map { appName($0.key) } ?? "your apps"
                return WeekInsight(
                    text: "You reach for \(who) most around \(timeText(hour: hour, calendar: calendar)). "
                        + "Set a \(timeText(hour: time.hour, minute: time.minute, calendar: calendar)) prayer reminder?",
                    actionTitle: "Set reminder",
                    action: .remind(hour: time.hour, minute: time.minute, appID: report.topApp?.key ?? ""))
            }
        }

        // 2. What came up most in prayer.
        if let mood = report.topMood, report.topMoodCount >= 2 {
            switch mood {
            case .anxious:
                return WeekInsight(text: "Anxious came up most when you prayed this week. Bring it to God again now?",
                                   actionTitle: "Pray about it", action: .prayTopic(.anxiety))
            case .tempted:
                return WeekInsight(text: "Tempted came up most this week. A one-minute prayer is there whenever it hits.",
                                   actionTitle: "Pray now", action: .prayTempted)
            case .tired:
                return WeekInsight(text: "Tired came up most this week. Close tonight with a short night prayer and rest.",
                                   actionTitle: "Night prayer", action: .nightPrayer)
            case .lonely:
                return WeekInsight(text: "Lonely came up most this week. Praying for a friend draws you both closer.",
                                   actionTitle: "Pray for a friend", action: .prayTopic(.friends))
            case .grateful, .joyful:
                return WeekInsight(text: "\(mood.title) came up most this week. Say thank you while it's fresh.",
                                   actionTitle: "Give thanks", action: .prayTopic(.gratitude))
            }
        }

        // 3. Wins and rhythm.
        if report.prayers.now == 0, report.daysPrayed == 0 {
            return WeekInsight(text: "One prayer today starts this week's rhythm. Thirty seconds is enough.",
                               actionTitle: "Pray now", action: .prayNow)
        }
        if report.putDown.now >= 2 {
            let minutes = Int(Double(report.putDown.now) * AppConstants.averageScrollSessionMinutes)
            return WeekInsight(text: "You chose not to scroll \(report.putDown.now) times this week. "
                                   + "That's about \(minutes) minutes back for the people around you.",
                               actionTitle: nil, action: nil)
        }
        if report.prayers.now > report.prayers.before, report.prayers.before > 0 {
            let more = report.prayers.delta
            return WeekInsight(text: "You prayed \(more) more \(more == 1 ? "time" : "times") than the week before. Keep the rhythm going.",
                               actionTitle: nil, action: nil)
        }
        if report.prayers.now < report.prayers.before {
            return WeekInsight(text: "A quieter week than the one before. One prayer tonight is a fresh start.",
                               actionTitle: "Night prayer", action: .nightPrayer)
        }
        if report.nightPrayers == 0 {
            return WeekInsight(text: "You prayed on \(report.daysPrayed) of the last 7 days. A night prayer is a gentle way to close each one.",
                               actionTitle: "Night prayer", action: .nightPrayer)
        }
        return WeekInsight(text: "You prayed on \(report.daysPrayed) of the last 7 days. Every one of them counts.",
                           actionTitle: nil, action: nil)
    }
}
