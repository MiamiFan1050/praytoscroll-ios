import Foundation
import SwiftData
import WidgetKit

/// Streak grace: "I prayed offline yesterday".
extension AppModel {
    /// Days logged as prayed offline (sessions flagged `.offline`).
    func offlineDays(calendar: Calendar = .current) -> [DayKey] {
        let offline = SessionSource.offline.rawValue
        let descriptor = FetchDescriptor<PrayerSession>(predicate: #Predicate { $0.sourceRaw == offline })
        return ((try? context.fetch(descriptor)) ?? []).map { DayKey($0.completedAt, calendar: calendar) }
    }

    /// Yesterday, when "I prayed offline yesterday" is on offer (see OfflineGrace).
    func offlineOffer(now: Date = Date()) -> DayKey? {
        let calendar = Calendar.current
        return OfflineGrace.offer(prayed: store.prayedDays, bridged: streak.frozenDays, offline: offlineDays(calendar: calendar),
                                  today: DayKey(now, calendar: calendar), calendar: calendar)
    }

    /// How many offline days are left this month (for the day on offer).
    func offlineRemaining(for day: DayKey) -> Int {
        OfflineGrace.remaining(inMonthOf: day, offline: offlineDays())
    }

    /// Logs yesterday as prayed offline: a flagged session at noon with no minutes. If a grace day was covering
    /// yesterday, it's given back for another day this week.
    @discardableResult
    func logOfflinePrayer(now: Date = Date()) -> Bool {
        guard let day = offlineOffer(now: now) else { return false }
        let calendar = Calendar.current
        let start = day.startDate(in: calendar)
        let noon = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: start) ?? start
        context.insert(PrayerSession(startedAt: noon, completedAt: noon, style: .quick, source: .offline))
        try? context.save()
        var frozen = store.frozenDays
        if frozen.remove(day) != nil { store.frozenDays = frozen }
        refreshStreak(now: now)
        refreshReminders()
        WidgetCenter.shared.reloadAllTimelines()
        Haptics.success()
        toast = streak.current > 1 ? "Yesterday counts. \(streak.current) days with God." : "Yesterday counts."
        return true
    }
}
