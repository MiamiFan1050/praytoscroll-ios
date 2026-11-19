import Foundation

/// One moment the app noticed, for "Your week". Kept on this iPhone only, in the app-group defaults.
struct ActivityEvent: Codable, Equatable, Sendable {
    enum Kind: String, Codable, Sendable {
        /// A gated app was opened and the gate looked (locked or open).
        case reach
        /// A prayer that came through the gate.
        case prayedFirst
        /// "I'm good, put it down" after a gate prayer: nothing opened.
        case putDown
        /// "I need it now": the emergency pass.
        case emergency
        /// The mood chip picked in a finished prayer (`detail` = PrayerMood raw value).
        case mood
        /// A Bible Stories episode watched to the end (`detail` = episode id).
        case story
        /// A finished Night prayer (Examen).
        case nightPrayer
    }

    var kind: Kind
    var at: Date
    /// The catalog id of the app ("instagram"), when there is one.
    var app: String?
    var detail: String?

    init(kind: Kind, at: Date, app: String? = nil, detail: String? = nil) {
        self.kind = kind
        self.at = at
        self.app = app
        self.detail = detail
    }
}

/// A small rolling log behind the "Your week" insights. Nothing here leaves the device and nothing is a counter
/// we can't recount: every number comes from these timestamps.
struct ActivityLog {
    static let key = "ak.activity.v1"
    /// Old events fall off; the insights only look at the last few weeks.
    static let keepDays: Double = 63
    static let maxEvents = 3000
    /// The Shortcuts trigger can fire twice for one open (app switcher, screenshots): one reach per app per minute.
    static let reachDedupeSeconds: TimeInterval = 60

    let defaults: UserDefaults

    init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    var events: [ActivityEvent] {
        guard let data = defaults.data(forKey: Self.key),
              let decoded = try? JSONDecoder().decode([ActivityEvent].self, from: data) else { return [] }
        return decoded
    }

    private func save(_ events: [ActivityEvent]) {
        guard let data = try? JSONEncoder().encode(events) else { return }
        defaults.set(data, forKey: Self.key)
    }

    /// Adds an event (sorted by time), trimming anything older than `keepDays` and capping the size.
    @discardableResult
    func record(_ kind: ActivityEvent.Kind, app: String? = nil, detail: String? = nil, at date: Date = Date()) -> Bool {
        var all = events
        if kind == .reach, let app,
           all.contains(where: { $0.kind == .reach && $0.app == app && abs($0.at.timeIntervalSince(date)) < Self.reachDedupeSeconds }) {
            return false
        }
        all.append(ActivityEvent(kind: kind, at: date, app: app, detail: detail))
        all.sort { $0.at < $1.at }
        let cutoff = date.addingTimeInterval(-Self.keepDays * 86_400)
        all.removeAll { $0.at < cutoff }
        if all.count > Self.maxEvents { all.removeFirst(all.count - Self.maxEvents) }
        save(all)
        return true
    }

    func events(_ kind: ActivityEvent.Kind, in interval: DateInterval) -> [ActivityEvent] {
        events.filter { $0.kind == kind && interval.contains($0.at) && $0.at < interval.end }
    }

    func count(_ kind: ActivityEvent.Kind, in interval: DateInterval) -> Int {
        events(kind, in: interval).count
    }

    func clear() {
        defaults.removeObject(forKey: Self.key)
    }
}

extension SharedStore {
    var activity: ActivityLog { ActivityLog(defaults: defaults) }
}

extension GateDecision {
    /// A real open by the person, for "the app you reach for most": the gate asked for a prayer, or let them into an
    /// open window. Not PrayToScroll's own reopen (launch pass), a bounce in the grace seconds, a test, a pause, or an
    /// app that isn't on the list.
    var isReach: Bool {
        switch self {
        case .requirePrayer: return true
        case .allow(_, let reason): return reason == .unlocked || reason == .dailyKey
        case .verifyTest: return false
        }
    }
}

/// The rolling 7 days "Your week" talks about: today and the 6 days before it, whatever weekday the calendar
/// starts on (so a Sunday-evening recap is a full week in every locale). Day edges follow the calendar's time zone,
/// so a week across a clock change is 167 or 169 hours, never a day short.
enum WeekWindow {
    static func current(now: Date, calendar: Calendar) -> DateInterval {
        let today = DayKey(now, calendar: calendar)
        let start = today.adding(days: -6, calendar: calendar).startDate(in: calendar)
        let end = today.adding(days: 1, calendar: calendar).startDate(in: calendar)
        return DateInterval(start: start, end: max(start, end))
    }

    /// The 7 days before `current`.
    static func previous(now: Date, calendar: Calendar) -> DateInterval {
        let today = DayKey(now, calendar: calendar)
        let start = today.adding(days: -13, calendar: calendar).startDate(in: calendar)
        let end = today.adding(days: -6, calendar: calendar).startDate(in: calendar)
        return DateInterval(start: start, end: max(start, end))
    }

    /// The 7 days of `current`, oldest first.
    static func days(now: Date, calendar: Calendar) -> [DayKey] {
        let today = DayKey(now, calendar: calendar)
        return (0..<7).reversed().map { today.adding(days: -$0, calendar: calendar) }
    }
}

/// "That's the 3rd time this week you chose not to scroll."
enum PutDownCopy {
    static func ordinal(_ n: Int) -> String {
        let suffix: String
        switch (n % 100, n % 10) {
        case (11...13, _): suffix = "th"
        case (_, 1): suffix = "st"
        case (_, 2): suffix = "nd"
        case (_, 3): suffix = "rd"
        default: suffix = "th"
        }
        return "\(n)\(suffix)"
    }

    /// The running count line, `count` including this time.
    static func countLine(_ count: Int) -> String {
        count <= 1 ? "Your first time this week choosing not to scroll."
            : "That's the \(ordinal(count)) time this week you chose not to scroll."
    }

    static let warmLines = [
        "Well chosen. The feed will keep.",
        "Phone down, heart up.",
        "Good call. Go be where you are.",
        "Enjoy the quiet. God is in it too.",
        "That's a real win. Go live it.",
    ]

    static func warmLine(for count: Int) -> String {
        warmLines[max(0, count - 1) % warmLines.count]
    }
}
