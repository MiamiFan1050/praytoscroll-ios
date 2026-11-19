import Foundation

/// A weekly rest day (a Sabbath) the person chose, from the day after they chose it.
struct RestPeriod: Codable, Equatable, Sendable {
    /// Calendar weekday: 1 = Sunday … 7 = Saturday.
    var weekday: Int
    var from: DayKey
    /// The last day it applied (nil while it's the current choice).
    var through: DayKey?
}

/// Rest days keep a streak alive without adding to it, the way a grace day does, but they don't use the week's grace
/// day. To stay honest:
/// - a choice starts tomorrow, never today or earlier
/// - there's at most one rest day in any 7 days, even if the weekday is switched
/// - praying on a rest day still counts as a prayed day
enum RestDays {
    /// Every rest day the periods give, up to and including `end`.
    static func days(_ periods: [RestPeriod], through end: DayKey, calendar: Calendar) -> Set<DayKey> {
        var candidates: Set<DayKey> = []
        for period in periods where (1...7).contains(period.weekday) {
            let last = min(period.through ?? end, end)
            guard period.from <= last else { continue }
            let first = calendar.component(.weekday, from: period.from.startDate(in: calendar))
            var cursor = period.from.adding(days: (period.weekday - first + 7) % 7, calendar: calendar)
            while cursor <= last {
                candidates.insert(cursor)
                cursor = cursor.adding(days: 7, calendar: calendar)
            }
        }
        var kept: [DayKey] = []
        for day in candidates.sorted() {
            if let previous = kept.last, previous.adding(days: 7, calendar: calendar) > day { continue }
            kept.append(day)
        }
        return Set(kept)
    }

    /// The weekday chosen now, if any.
    static func current(_ periods: [RestPeriod]) -> Int? {
        periods.last { $0.through == nil }?.weekday
    }

    /// Choose a rest weekday today (nil turns it off). The current choice ends today; a new one starts tomorrow.
    static func choosing(_ weekday: Int?, in periods: [RestPeriod], today: DayKey, calendar: Calendar) -> [RestPeriod] {
        if weekday == current(periods) { return periods }
        var result = periods
        if let index = result.lastIndex(where: { $0.through == nil }) {
            if result[index].from > today {
                result.remove(at: index)   // picked earlier today and not started yet: just replace it
            } else {
                result[index].through = today
            }
        }
        if let weekday, (1...7).contains(weekday) {
            result.append(RestPeriod(weekday: weekday, from: today.adding(days: 1, calendar: calendar), through: nil))
        }
        return Array(result.suffix(60))
    }
}
