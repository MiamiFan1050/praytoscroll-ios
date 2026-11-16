import Foundation

struct ChallengeProgress: Equatable, Sendable {
    var completed: Int
    var target: Int
    /// 1-based day of the challenge (can exceed `days` once the window is over).
    var dayIndex: Int
    var days: Int
    var isComplete: Bool
    /// The target can no longer be reached inside the window.
    var isExpired: Bool
    var completedToday: Bool

    var fraction: Double { target > 0 ? min(1, Double(completed) / Double(target)) : 0 }
    var remaining: Int { max(0, target - completed) }
}

/// Pure challenge progress logic.
enum ChallengeEngine {
    static func progress(definition: ChallengeDefinition, startedAt: Date, now: Date, prayedDays: Set<DayKey>,
                         peoplePrayedFor: [(name: String, date: Date)], calendar: Calendar) -> ChallengeProgress {
        let start = DayKey(startedAt, calendar: calendar)
        let today = DayKey(now, calendar: calendar)
        let dayIndex = max(1, start.days(until: today, calendar: calendar) + 1)
        let lastDay = start.adding(days: definition.days - 1, calendar: calendar)
        let target = max(1, definition.target)

        let completed: Int
        let completedToday: Bool
        switch definition.metric {
        case .prayedDays:
            let inWindow = prayedDays.filter { $0 >= start && $0 <= lastDay }
            completed = min(target, inWindow.count)
            completedToday = prayedDays.contains(today)
        case .distinctPeople:
            let startDate = start.startDate(in: calendar)
            let endDate = lastDay.adding(days: 1, calendar: calendar).startDate(in: calendar)
            let names = peoplePrayedFor
                .filter { $0.date >= startDate && $0.date < endDate }
                .map { $0.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
                .filter { !$0.isEmpty }
            completed = min(target, Set(names).count)
            completedToday = peoplePrayedFor.contains { DayKey($0.date, calendar: calendar) == today }
        }

        let isComplete = completed >= target
        let daysLeftIncludingToday = max(0, today.days(until: lastDay, calendar: calendar) + 1)
        let isExpired: Bool
        switch definition.metric {
        case .prayedDays:
            // Each remaining day (including today if not yet prayed) can add at most one.
            let possible = daysLeftIncludingToday - (prayedDays.contains(today) && today <= lastDay ? 1 : 0)
            isExpired = !isComplete && (target - completed) > max(0, possible)
        case .distinctPeople:
            isExpired = !isComplete && today > lastDay
        }

        return ChallengeProgress(completed: completed, target: target, dayIndex: dayIndex, days: definition.days,
                                 isComplete: isComplete, isExpired: isExpired, completedToday: completedToday)
    }
}
