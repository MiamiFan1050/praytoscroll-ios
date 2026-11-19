import Foundation

/// "I prayed offline yesterday": if you prayed away from the app (at church, with family, before bed), yesterday can
/// still count for your streak. It's honest by design:
/// - only for yesterday, and only when no prayer was logged then
/// - only when it keeps a streak going (the day before was prayed or covered)
/// - at most twice in a calendar month
/// - stored as a session flagged `.offline`, with no minutes and not counted as an in-app prayer
enum OfflineGrace {
    static let perMonth = 2

    /// Offline days already logged in the month that `day` falls in.
    static func used(inMonthOf day: DayKey, offline: [DayKey]) -> Int {
        Set(offline).filter { $0.year == day.year && $0.month == day.month }.count
    }

    /// How many are left for the month that `day` falls in.
    static func remaining(inMonthOf day: DayKey, offline: [DayKey]) -> Int {
        max(0, perMonth - used(inMonthOf: day, offline: offline))
    }

    /// The day you can log (yesterday), or nil if logging it isn't allowed or wouldn't change anything.
    /// `bridged` is any day that already keeps a chain alive without a prayer (a grace day or a rest day).
    static func offer(prayed: Set<DayKey>, bridged: Set<DayKey>, offline: [DayKey], today: DayKey, calendar: Calendar) -> DayKey? {
        let yesterday = today.adding(days: -1, calendar: calendar)
        guard !prayed.contains(yesterday) else { return nil }
        guard remaining(inMonthOf: yesterday, offline: offline) > 0 else { return nil }
        let before = yesterday.adding(days: -1, calendar: calendar)
        guard prayed.contains(before) || bridged.contains(before) else { return nil }
        return yesterday
    }
}
