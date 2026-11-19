import Foundation

struct StreakSummary: Equatable, Sendable {
    var current: Int
    var longest: Int
    var prayedToday: Bool
    var totalDaysPrayed: Int
    var freezeAvailableThisWeek: Bool
    /// The streak is alive but today has no prayer yet.
    var atRisk: Bool
    var frozenDays: Set<DayKey>
    /// Rest days (a chosen weekly Sabbath): they keep the chain like a grace day, without using it.
    var restDays: Set<DayKey> = []
    /// Today is a rest day: nothing is at risk.
    var isRestDay: Bool = false

    static let empty = StreakSummary(current: 0, longest: 0, prayedToday: false, totalDaysPrayed: 0,
                                     freezeAvailableThisWeek: true, atRisk: false, frozenDays: [])
}

/// Pure streak logic. A streak is a chain of consecutive days where each day was either prayed, covered by a
/// streak freeze, or a chosen rest day. Only prayed days add to the number; frozen and rest days just keep the
/// chain alive. Each calendar week has exactly one freeze, applied automatically to a missed day.
enum StreakEngine {
    static let maxBridgeableGap = 7

    static func freezeUsed(inWeekOf day: DayKey, frozen: Set<DayKey>, calendar: Calendar) -> Bool {
        let week = WeekID(day, calendar: calendar)
        return frozen.contains { WeekID($0, calendar: calendar) == week }
    }

    /// Applies streak freezes to missed days between the last active day and today (exclusive).
    /// Freezes are only spent when they save the whole gap, so a broken streak never burns a freeze.
    static func reconcileFreezes(prayed: Set<DayKey>, frozen: Set<DayKey>, rest: Set<DayKey> = [], today: DayKey,
                                 calendar: Calendar) -> Set<DayKey> {
        let active = prayed.union(frozen).union(rest)
        guard let lastActive = active.filter({ $0 < today }).max() else { return frozen }
        let yesterday = today.adding(days: -1, calendar: calendar)
        guard lastActive < yesterday else { return frozen }
        // A run of rest days with no prayer in it keeps nothing alive, so it never spends a freeze.
        var probe = lastActive
        while !prayed.contains(probe) {
            probe = probe.adding(days: -1, calendar: calendar)
            if !active.contains(probe) { return frozen }
        }

        var gap: [DayKey] = []
        var cursor = lastActive.adding(days: 1, calendar: calendar)
        while cursor < today {
            gap.append(cursor)
            if gap.count > maxBridgeableGap { return frozen }
            cursor = cursor.adding(days: 1, calendar: calendar)
        }

        var tentative = frozen
        for day in gap {
            if freezeUsed(inWeekOf: day, frozen: tentative, calendar: calendar) { return frozen }
            tentative.insert(day)
        }
        return tentative
    }

    static func summary(prayed: Set<DayKey>, frozen: Set<DayKey>, rest: Set<DayKey> = [], today: DayKey,
                        calendar: Calendar) -> StreakSummary {
        let prayedToday = prayed.contains(today)
        let active = prayed.union(frozen).union(rest)
        let restToday = rest.contains(today)

        var current = 0
        var cursor = prayedToday ? today : today.adding(days: -1, calendar: calendar)
        while active.contains(cursor) {
            if prayed.contains(cursor) { current += 1 }
            cursor = cursor.adding(days: -1, calendar: calendar)
        }

        let longest = max(current, longestChain(prayed: prayed, frozen: frozen, rest: rest, calendar: calendar))
        let freezeAvailable = !freezeUsed(inWeekOf: today, frozen: frozen, calendar: calendar)

        return StreakSummary(
            current: current,
            longest: longest,
            prayedToday: prayedToday,
            totalDaysPrayed: prayed.count,
            freezeAvailableThisWeek: freezeAvailable,
            atRisk: !prayedToday && current > 0 && !restToday,
            frozenDays: frozen,
            restDays: rest,
            isRestDay: restToday
        )
    }

    static func longestChain(prayed: Set<DayKey>, frozen: Set<DayKey>, rest: Set<DayKey> = [], calendar: Calendar) -> Int {
        let active = prayed.union(frozen).union(rest).sorted()
        guard !active.isEmpty else { return 0 }
        var best = 0
        var run = 0
        var previous: DayKey?
        for day in active {
            if let previous, previous.adding(days: 1, calendar: calendar) == day {
                // chain continues
            } else {
                run = 0
            }
            if prayed.contains(day) { run += 1 }
            best = max(best, run)
            previous = day
        }
        return best
    }
}

/// Streak milestones and their badges.
enum MilestoneEngine {
    static let milestones = [3, 7, 14, 21, 30, 50, 100, 365]

    static func newlyEarned(streak: Int, alreadyAwarded: Set<Int>) -> [Int] {
        milestones.filter { $0 <= streak && !alreadyAwarded.contains($0) }
    }

    static func next(after streak: Int) -> Int? {
        milestones.first { $0 > streak }
    }

    static func title(for milestone: Int) -> String {
        switch milestone {
        case 3: return "First Light"
        case 7: return "One Full Week"
        case 14: return "Two Weeks Faithful"
        case 21: return "A New Habit"
        case 30: return "Thirty Days"
        case 50: return "Jubilee"
        case 100: return "Century of Prayer"
        case 365: return "A Year of Amen"
        default: return "\(milestone) Days"
        }
    }

    static func symbol(for milestone: Int) -> String {
        switch milestone {
        case 3: return "sunrise.fill"
        case 7: return "leaf.fill"
        case 14: return "star.fill"
        case 21: return "flame.fill"
        case 30: return "moon.stars.fill"
        case 50: return "sparkles"
        case 100: return "crown.fill"
        case 365: return "sun.max.fill"
        default: return "seal.fill"
        }
    }
}
