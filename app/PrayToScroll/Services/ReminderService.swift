import Foundation
import UserNotifications

/// All local notifications: daily prayer time, streak at risk at 8 PM, morning verse, the Sunday recap,
/// "before you scroll", and the window-end nudge.
@MainActor
final class ReminderService {
    static let shared = ReminderService()

    private let center = UNUserNotificationCenter.current()
    private var lastRefresh: Date?

    private enum ID {
        static let daily = "ak.daily"
        static let riskPrefix = "ak.risk."
        static let versePrefix = "ak.verse."
        static let windowEnd = "ak.window.end"
        static let weekly = "ak.week.recap"
        static let nudge = "ak.nudge"
        static let night = "ak.night"
        static let all = [daily, weekly, nudge, night]
    }

    func requestAuthorization() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    func refreshIfNeeded(model: AppModel) {
        if let lastRefresh, Date().timeIntervalSince(lastRefresh) < 600,
           Calendar.current.isDate(lastRefresh, inSameDayAs: Date()) { return }
        model.refreshReminders()
    }

    func refresh(settings: AppSettings, streak: StreakSummary, verses: VerseProvider, copy: CopyBook, now: Date = Date()) {
        lastRefresh = now
        guard settings.hasOnboarded else { return }
        Task {
            let status = await authorizationStatus()
            guard status == .authorized || status == .provisional || status == .ephemeral else { return }
            await reschedule(settings: settings, streak: streak, verses: verses, copy: copy, now: now)
        }
    }

    private func reschedule(settings: AppSettings, streak: StreakSummary, verses: VerseProvider, copy: CopyBook, now: Date) async {
        let pending = await center.pendingNotificationRequests()
        let ours = pending.map(\.identifier).filter { ID.all.contains($0) || $0.hasPrefix(ID.riskPrefix) || $0.hasPrefix(ID.versePrefix) }
        center.removePendingNotificationRequests(withIdentifiers: ours)

        let calendar = Calendar.current
        let name = settings.firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        let r = settings.reminders

        if r.dailyEnabled {
            let content = UNMutableNotificationContent()
            let message = copy.message("notifications.dailyReminder")
                ?? (title: "Time to pray, {name}", body: "A few quiet minutes with God. Knees before feeds.")
            content.title = CopyBook.fill(message.title, name: name)
            content.body = CopyBook.fill(message.body, name: name)
            content.sound = .default
            content.userInfo = ["url": AppLinks.prayDeepLink.absoluteString]
            var parts = DateComponents()
            parts.hour = r.dailyHour
            parts.minute = r.dailyMinute
            add(ID.daily, content, UNCalendarNotificationTrigger(dateMatching: parts, repeats: true))
        }

        if r.streakAtRiskEnabled {
            let today = DayKey(now, calendar: calendar)
            for offset in 0..<7 {
                let day = today.adding(days: offset, calendar: calendar)
                guard let fire = calendar.date(bySettingHour: 20, minute: 0, second: 0, of: day.noonDate(in: calendar)), fire > now else { continue }
                if offset == 0 && (streak.prayedToday || streak.current == 0) { continue }
                let content = UNMutableNotificationContent()
                if offset == 0, let message = copy.message("notifications.streakAtRisk") {
                    content.title = CopyBook.fill(message.title, name: name, streak: streak.current)
                    content.body = CopyBook.fill(message.body, name: name, streak: streak.current)
                } else if offset == 0 {
                    content.title = "Keep your \(streak.current)-day streak"
                    content.body = "Pray before midnight to keep it going. Thirty seconds is enough."
                } else {
                    // Future days: the streak number isn't known yet, so no number.
                    content.title = "Still time today"
                    content.body = "You haven't prayed yet today. One short prayer keeps your streak alive."
                }
                content.sound = .default
                content.userInfo = ["url": AppLinks.prayDeepLink.absoluteString]
                let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
                add(ID.riskPrefix + day.string, content, UNCalendarNotificationTrigger(dateMatching: parts, repeats: false))
            }
        }

        if r.weeklyRecapEnabled {
            // Gregorian weekday 1 is Sunday whatever day the person's week starts on.
            let content = UNMutableNotificationContent()
            content.title = "Your week with God is ready"
            content.body = "Your prayers, the times you chose not to scroll, and one idea for the week ahead."
            content.sound = nil
            content.userInfo = ["url": AppLinks.statsDeepLink.absoluteString]
            var parts = DateComponents()
            parts.weekday = 1
            parts.hour = 19
            parts.minute = 0
            add(ID.weekly, content, UNCalendarNotificationTrigger(dateMatching: parts, repeats: true))
        }

        if r.nudgeEnabled {
            let app = AppCatalog.app(id: r.nudgeAppID, customApps: settings.customApps)?.name
            let content = UNMutableNotificationContent()
            content.title = app.map { "Before you open \($0)" } ?? "Before you scroll"
            content.body = name.isEmpty ? "A short prayer first. Thirty seconds is enough." : "A short prayer first, \(name). Thirty seconds is enough."
            content.sound = .default
            content.userInfo = ["url": AppLinks.prayDeepLink.absoluteString]
            var parts = DateComponents()
            parts.hour = r.nudgeHour
            parts.minute = r.nudgeMinute
            add(ID.nudge, content, UNCalendarNotificationTrigger(dateMatching: parts, repeats: true))
        }

        if r.bedtimeEnabled {
            let content = UNMutableNotificationContent()
            content.title = NightPrayer.title
            content.body = "A few quiet minutes to look back on today with God, then rest."
            content.sound = nil
            content.userInfo = ["url": AppLinks.nightPrayerDeepLink.absoluteString]
            var parts = DateComponents()
            parts.hour = r.bedtimeHour
            parts.minute = r.bedtimeMinute
            add(ID.night, content, UNCalendarNotificationTrigger(dateMatching: parts, repeats: true))
        }

        if r.morningVerseEnabled {
            let today = DayKey(now, calendar: calendar)
            for offset in 0..<10 {
                let day = today.adding(days: offset, calendar: calendar)
                guard let fire = calendar.date(bySettingHour: r.morningHour, minute: r.morningMinute, second: 0, of: day.noonDate(in: calendar)),
                      fire > now else { continue }
                let verse = verses.verse(for: fire, calendar: calendar)
                let content = UNMutableNotificationContent()
                if let message = copy.message("notifications.morningVerse") {
                    content.title = CopyBook.fill(message.title, name: name, verse: verse)
                    content.body = CopyBook.fill(message.body, name: name, verse: verse)
                } else {
                    content.title = verse.ref
                    content.body = verse.displayText
                }
                content.sound = nil
                content.userInfo = ["url": AppLinks.prayDeepLink.absoluteString]
                let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
                add(ID.versePrefix + day.string, content, UNCalendarNotificationTrigger(dateMatching: parts, repeats: false))
            }
        }
    }

    /// "Your 15 minutes are up." A Shortcuts gate can't close an app, so a gentle nudge closes the loop.
    /// The "time's up" nudge at the end of an unlock window (replaces any earlier one). nil `minutes` = cancel only.
    func scheduleWindowEnd(at date: Date, minutes: Int?, enabled: Bool) {
        center.removePendingNotificationRequests(withIdentifiers: [ID.windowEnd])
        guard enabled, let minutes else { return }
        let interval = date.timeIntervalSinceNow
        guard interval > 5 else { return }
        Task {
            let status = await authorizationStatus()
            guard status == .authorized || status == .provisional || status == .ephemeral else { return }
            let content = UNMutableNotificationContent()
            content.title = minutes == 60 ? "Your hour is up" : "Your \(UnlockChoice.spoken(minutes: minutes)) are up"
            content.body = "\(AppConstants.appName)'s waiting 🙏 Ready to put it down?"
            content.sound = .default
            content.userInfo = ["url": AppLinks.prayDeepLink.absoluteString]
            add(ID.windowEnd, content, UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false))
        }
    }

    func cancelAll() {
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
    }

    private func add(_ id: String, _ content: UNMutableNotificationContent, _ trigger: UNNotificationTrigger) {
        center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger)) { _ in }
    }
}
