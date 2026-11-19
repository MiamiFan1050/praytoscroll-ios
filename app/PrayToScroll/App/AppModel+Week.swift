import Foundation
import SwiftData
import UserNotifications

/// "Your week" on Progress: the numbers, the one insight, its action and the share card.
extension AppModel {
    func weekReport(now: Date = Date(), calendar: Calendar = .current) -> WeekReport {
        let sessions = allSessions().map {
            WeekSessionFact(completedAt: $0.completedAt, durationSeconds: $0.durationSeconds, personName: $0.personName,
                            isGate: $0.source == .gate, isTimedPrayer: $0.source != .offline)
        }
        let answered = ((try? context.fetch(FetchDescriptor<PrayerRequest>())) ?? []).compactMap(\.answeredAt)
        let saved = ((try? context.fetch(FetchDescriptor<SavedVerse>())) ?? []).map(\.savedAt)
        return WeekReport.make(now: now, calendar: calendar, sessions: sessions, answeredAt: answered, savedAt: saved,
                               readByDay: wordProgress.readByDay, events: store.activity.events, streak: streak.current)
    }

    func weekInsight(for report: WeekReport, calendar: Calendar = .current) -> WeekInsight {
        let reminders = settings.reminders
        return WeekInsightEngine.make(report: report, appName: { self.appName(for: $0) }, calendar: calendar,
                                      nudge: reminders.nudgeEnabled ? (hour: reminders.nudgeHour, minute: reminders.nudgeMinute) : nil)
    }

    /// A gated app's name by catalog id ("instagram" → "Instagram").
    func appName(for id: String) -> String {
        gatedApp(id: id)?.name ?? id.capitalized
    }

    /// The insight's one tap.
    func perform(_ action: WeekInsight.Action) {
        switch action {
        case .remind(let hour, let minute, let appID):
            setScrollNudge(hour: hour, minute: minute, appID: appID)
        case .prayTopic(let topic):
            startPrayer(style: .quick, source: .manual, topic: topic)
        case .prayTempted:
            startPrayer(style: .quick, source: .manual, mood: .tempted)
        case .nightPrayer:
            startNightPrayer()
        case .prayNow:
            startPrayer(source: .manual)
        }
    }

    /// "Set a 9:45 PM prayer reminder": turns on the before-you-scroll reminder (ReminderService schedules it, only
    /// when notifications are allowed). Asks for notifications the first time.
    func setScrollNudge(hour: Int, minute: Int, appID: String) {
        updateSettings { s in
            s.reminders.nudgeEnabled = true
            s.reminders.nudgeHour = min(23, max(0, hour))
            s.reminders.nudgeMinute = min(59, max(0, minute))
            s.reminders.nudgeAppID = appID
        }
        let time = WeekInsightEngine.timeText(hour: hour, minute: minute, calendar: .current)
        Haptics.success()
        Task {
            let reminders = ReminderService.shared
            if await reminders.authorizationStatus() == .notDetermined {
                _ = await reminders.requestAuthorization()
                refreshReminders()
            }
            let status = await reminders.authorizationStatus()
            toast = status == .denied ? "Saved. Turn on notifications in Settings to get it." : "Prayer reminder set for \(time)"
        }
    }

    /// What the "My week with God" share card shows.
    func weekShareData(_ report: WeekReport, calendar: Calendar = .current) -> WeekShareData {
        let letters = calendar.veryShortStandaloneWeekdaySymbols
        return WeekShareData(prayers: report.prayers.now, minutes: report.minutes.now, prayedOn: report.prayedOn,
                             dayLetters: report.days.map { day in
                                 let weekday = calendar.component(.weekday, from: day.noonDate(in: calendar))
                                 return letters.indices.contains(weekday - 1) ? letters[weekday - 1] : ""
                             },
                             putDown: report.putDown.now, prayedFirst: report.prayedFirst.now, streak: report.streak)
    }
}
