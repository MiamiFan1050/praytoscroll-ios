import Foundation
@testable import PrayToScroll

/// A fixed calendar so tests don't depend on the machine's locale, time zone or first weekday.
enum TestCalendar {
    static let newYork: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        calendar.firstWeekday = 2 // weeks start on Monday
        calendar.minimumDaysInFirstWeek = 4
        calendar.locale = Locale(identifier: "en_US_POSIX")
        return calendar
    }()

    static func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 12, _ minute: Int = 0, _ second: Int = 0) -> Date {
        var parts = DateComponents()
        parts.year = year
        parts.month = month
        parts.day = day
        parts.hour = hour
        parts.minute = minute
        parts.second = second
        return newYork.date(from: parts)!
    }

    static func day(_ year: Int, _ month: Int, _ day: Int) -> DayKey {
        DayKey(year: year, month: month, day: day)
    }

    /// Consecutive days ending at (and including) `last`.
    static func days(count: Int, endingAt last: DayKey) -> Set<DayKey> {
        Set((0..<count).map { last.adding(days: -$0, calendar: newYork) })
    }
}

/// Deterministic RNG for shuffle-bag tests.
struct SplitMix64: RandomNumberGenerator {
    var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

/// A throwaway UserDefaults domain per test.
func makeScratchDefaults(_ name: String = UUID().uuidString) -> UserDefaults {
    let suite = "praytoscroll.tests.\(name)"
    let defaults = UserDefaults(suiteName: suite)!
    defaults.removePersistentDomain(forName: suite)
    return defaults
}
