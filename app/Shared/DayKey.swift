import Foundation

/// A calendar day in the user's calendar, independent of time of day ("2026-11-16").
struct DayKey: Hashable, Comparable, Codable, Sendable, CustomStringConvertible {
    let year: Int
    let month: Int
    let day: Int

    init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    init(_ date: Date, calendar: Calendar = .current) {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        self.init(year: parts.year ?? 1970, month: parts.month ?? 1, day: parts.day ?? 1)
    }

    init?(string: String) {
        let parts = string.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3, (1...12).contains(parts[1]), (1...31).contains(parts[2]) else { return nil }
        self.init(year: parts[0], month: parts[1], day: parts[2])
    }

    var string: String { String(format: "%04d-%02d-%02d", year, month, day) }
    var description: String { string }

    func startDate(in calendar: Calendar = .current) -> Date {
        var parts = DateComponents()
        parts.year = year
        parts.month = month
        parts.day = day
        parts.hour = 0
        return calendar.date(from: parts) ?? Date(timeIntervalSince1970: 0)
    }

    /// Noon avoids DST edge cases when doing day arithmetic.
    func noonDate(in calendar: Calendar = .current) -> Date {
        var parts = DateComponents()
        parts.year = year
        parts.month = month
        parts.day = day
        parts.hour = 12
        return calendar.date(from: parts) ?? Date(timeIntervalSince1970: 0)
    }

    func adding(days: Int, calendar: Calendar = .current) -> DayKey {
        let date = calendar.date(byAdding: .day, value: days, to: noonDate(in: calendar)) ?? noonDate(in: calendar)
        return DayKey(date, calendar: calendar)
    }

    func days(until other: DayKey, calendar: Calendar = .current) -> Int {
        calendar.dateComponents([.day], from: noonDate(in: calendar), to: other.noonDate(in: calendar)).day ?? 0
    }

    var previous: DayKey { adding(days: -1) }
    var next: DayKey { adding(days: 1) }

    static func < (lhs: DayKey, rhs: DayKey) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }

    static func today(calendar: Calendar = .current, now: Date = Date()) -> DayKey {
        DayKey(now, calendar: calendar)
    }

    /// 1...366, used to pick the verse of the day.
    func dayOfYear(calendar: Calendar = .current) -> Int {
        calendar.ordinality(of: .day, in: .year, for: noonDate(in: calendar)) ?? 1
    }
}

/// Identifies a calendar week (for the "one streak freeze per week" rule).
struct WeekID: Hashable, Sendable {
    let yearForWeek: Int
    let week: Int

    init(_ day: DayKey, calendar: Calendar) {
        let parts = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: day.noonDate(in: calendar))
        yearForWeek = parts.yearForWeekOfYear ?? day.year
        week = parts.weekOfYear ?? 1
    }
}
