import XCTest
@testable import PrayToScroll

/// "Your week": the rolling 7-day window (start, clock changes, time zones), the numbers, and the one insight.
final class WeekReportTests: XCTestCase {
    private let ny = TestCalendar.newYork

    private func calendar(_ zone: String, firstWeekday: Int = 1) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: zone)!
        calendar.firstWeekday = firstWeekday
        calendar.locale = Locale(identifier: "en_US_POSIX")
        return calendar
    }

    /// Formatters put a narrow no-break space before AM/PM; compare as plain spaces.
    private func plain(_ text: String) -> String {
        text.replacingOccurrences(of: "\u{202F}", with: " ").replacingOccurrences(of: "\u{00A0}", with: " ")
    }

    private func prayer(_ date: Date, minutes: Double = 2, person: String = "", gate: Bool = false) -> WeekSessionFact {
        WeekSessionFact(completedAt: date, durationSeconds: minutes * 60, personName: person, isGate: gate)
    }

    // MARK: Week math

    func testTheWeekIsTodayAndTheSixDaysBefore() {
        let now = TestCalendar.date(2026, 11, 18, 21, 30)   // a Wednesday evening
        let week = WeekWindow.current(now: now, calendar: ny)
        XCTAssertEqual(week.start, TestCalendar.date(2026, 11, 12, 0, 0), "starts at midnight six days ago")
        XCTAssertEqual(week.end, TestCalendar.date(2026, 11, 19, 0, 0), "ends tonight at midnight")
        XCTAssertEqual(WeekWindow.previous(now: now, calendar: ny).end, week.start, "last week ends where this one starts")
        XCTAssertEqual(WeekWindow.previous(now: now, calendar: ny).start, TestCalendar.date(2026, 11, 5, 0, 0))
        XCTAssertEqual(WeekWindow.days(now: now, calendar: ny).map(\.string),
                       ["2026-11-12", "2026-11-13", "2026-11-14", "2026-11-15", "2026-11-16", "2026-11-17", "2026-11-18"])
        // 00:00 and 23:59 on the same day give the same week.
        XCTAssertEqual(WeekWindow.current(now: TestCalendar.date(2026, 11, 18, 0, 0, 1), calendar: ny), week)
        XCTAssertEqual(WeekWindow.current(now: TestCalendar.date(2026, 11, 18, 23, 59, 59), calendar: ny), week)
    }

    func testTheWeekDoesNotDependOnTheFirstWeekday() {
        let now = TestCalendar.date(2026, 11, 15, 19, 0)   // Sunday 7 PM, when the recap arrives
        var sundayFirst = ny
        sundayFirst.firstWeekday = 1
        XCTAssertEqual(WeekWindow.current(now: now, calendar: sundayFirst), WeekWindow.current(now: now, calendar: ny),
                       "a Sunday recap is a full 7 days in the US too, not the 19 hours since the calendar week began")
        XCTAssertEqual(WeekWindow.current(now: now, calendar: ny).duration, 7 * 86_400)
    }

    func testAWeekAcrossAClockChangeIsStillSevenDays() {
        // US clocks fell back on Sunday Nov 1, 2026 and sprang forward on Sunday Mar 8, 2026.
        let fall = WeekWindow.current(now: TestCalendar.date(2026, 11, 5, 9, 0), calendar: ny)
        XCTAssertEqual(fall.start, TestCalendar.date(2026, 10, 30, 0, 0))
        XCTAssertEqual(fall.duration, 169 * 3600, "an extra hour, not an extra day")
        let spring = WeekWindow.current(now: TestCalendar.date(2026, 3, 10, 9, 0), calendar: ny)
        XCTAssertEqual(spring.start, TestCalendar.date(2026, 3, 4, 0, 0))
        XCTAssertEqual(spring.duration, 167 * 3600)
        XCTAssertEqual(WeekWindow.days(now: TestCalendar.date(2026, 11, 5, 9, 0), calendar: ny).count, 7)

        // A late prayer on the night the clocks change lands on its own day.
        let sessions = [prayer(TestCalendar.date(2026, 11, 1, 23, 30)), prayer(TestCalendar.date(2026, 11, 1, 1, 30))]
        let report = WeekReport.make(now: TestCalendar.date(2026, 11, 5, 9, 0), calendar: ny, sessions: sessions)
        XCTAssertEqual(report.prayers.now, 2)
        XCTAssertEqual(report.daysPrayed, 1, "both on Sunday Nov 1")
        XCTAssertEqual(report.prayedOn, [false, false, true, false, false, false, false], "Oct 30, 31, Nov 1…")
    }

    func testTimeZonesMoveTheDayAndTheHour() {
        // 11:30 PM in New York is 1:30 PM the next day in Tokyo.
        let late = TestCalendar.date(2026, 11, 18, 23, 30)
        let events = (0..<3).map { ActivityEvent(kind: .reach, at: late.addingTimeInterval(Double($0) * -86_400), app: "instagram") }
        let nyReport = WeekReport.make(now: late, calendar: ny, sessions: [prayer(late)], events: events)
        XCTAssertEqual(nyReport.topHourValue, 23)
        XCTAssertEqual(nyReport.prayedOn.last, true, "today in New York")

        let tokyo = calendar("Asia/Tokyo")
        let tokyoReport = WeekReport.make(now: late, calendar: tokyo, sessions: [prayer(late)], events: events)
        XCTAssertEqual(tokyoReport.topHourValue, 13)
        XCTAssertEqual(tokyoReport.days.last?.string, "2026-11-19")
        XCTAssertEqual(tokyoReport.prayedOn.last, true, "the same prayer is 'today' on Nov 19 in Tokyo")
    }

    // MARK: Numbers

    func testEmptyDataIsAnEmptyWeekWithAStartingInsight() {
        let report = WeekReport.make(now: TestCalendar.date(2026, 11, 18), calendar: ny, sessions: [])
        XCTAssertTrue(report.isEmpty)
        XCTAssertEqual(report.prayers, WeekReport.Pair(now: 0, before: 0))
        XCTAssertEqual(report.minutes.now, 0)
        XCTAssertEqual(report.daysPrayed, 0)
        XCTAssertNil(report.topApp)
        XCTAssertNil(report.topHour)
        XCTAssertNil(report.topMood)
        let insight = WeekInsightEngine.make(report: report, appName: { $0 }, calendar: ny)
        XCTAssertEqual(insight.action, .prayNow)
        XCTAssertTrue(insight.text.hasPrefix("Your week starts with one prayer"))
    }

    func testThisWeekAgainstLastWeek() {
        let now = TestCalendar.date(2026, 11, 18, 21, 0)
        let sessions = [
            prayer(TestCalendar.date(2026, 11, 18, 7, 0), minutes: 3, person: "Sam"),
            prayer(TestCalendar.date(2026, 11, 17, 22, 0), minutes: 1.5, gate: true),
            prayer(TestCalendar.date(2026, 11, 12, 0, 5), minutes: 2, person: "sam "),   // first minutes of the week
            prayer(TestCalendar.date(2026, 11, 11, 23, 55), minutes: 5),                  // last minutes of the week before
            prayer(TestCalendar.date(2026, 11, 6, 12, 0), minutes: 5, person: "Ana"),
            WeekSessionFact(completedAt: TestCalendar.date(2026, 11, 14, 12, 0), durationSeconds: 0, isTimedPrayer: false),
        ]
        let events = [
            ActivityEvent(kind: .putDown, at: TestCalendar.date(2026, 11, 17, 22, 1), app: "instagram"),
            ActivityEvent(kind: .putDown, at: TestCalendar.date(2026, 11, 10, 22, 1), app: "instagram"),
            ActivityEvent(kind: .story, at: TestCalendar.date(2026, 11, 16, 20, 0), detail: "noah-1"),
            ActivityEvent(kind: .emergency, at: TestCalendar.date(2026, 11, 15, 9, 0), app: "tiktok"),
        ]
        let report = WeekReport.make(now: now, calendar: ny, sessions: sessions,
                                     answeredAt: [TestCalendar.date(2026, 11, 13), TestCalendar.date(2026, 10, 1)],
                                     savedAt: [TestCalendar.date(2026, 11, 18, 8, 0)],
                                     readByDay: ["2026-11-18": 10, "2026-11-12": 4, "2026-11-11": 50],
                                     events: events, streak: 9)
        XCTAssertEqual(report.prayers, WeekReport.Pair(now: 3, before: 2), "the offline day keeps the streak but isn't a timed prayer")
        XCTAssertEqual(report.prayers.delta, 1)
        XCTAssertEqual(report.minutes.now, 7, "3 + 1.5 + 2 = 6.5, rounded")
        XCTAssertEqual(report.minutes.before, 10)
        XCTAssertEqual(report.daysPrayed, 4, "Nov 12, 14 (offline), 17 and 18")
        XCTAssertEqual(report.peoplePrayedFor, 1, "Sam once, whatever the spelling")
        XCTAssertEqual(report.answered, 1)
        XCTAssertEqual(report.versesSaved, 1)
        XCTAssertEqual(report.versesRead, 14)
        XCTAssertEqual(report.storiesWatched, 1)
        XCTAssertEqual(report.emergencyPasses, 1)
        XCTAssertEqual(report.putDown, WeekReport.Pair(now: 1, before: 1))
        XCTAssertEqual(report.prayedFirst.now, 1, "the gate prayer counts even with no log entry")
        XCTAssertEqual(report.streak, 9)
        XCTAssertFalse(report.isEmpty)
    }

    func testTheAppAndHourYouReachForMost() {
        let now = TestCalendar.date(2026, 11, 18, 23, 0)
        var events: [ActivityEvent] = []
        for day in 13...18 { events.append(ActivityEvent(kind: .reach, at: TestCalendar.date(2026, 11, day, 22, 10), app: "instagram")) }
        for day in 16...17 { events.append(ActivityEvent(kind: .reach, at: TestCalendar.date(2026, 11, day, 13, 0), app: "tiktok")) }
        events.append(ActivityEvent(kind: .reach, at: TestCalendar.date(2026, 11, 18, 13, 5), app: GateEngine.anyAppID))
        events.append(ActivityEvent(kind: .reach, at: TestCalendar.date(2026, 11, 2, 9, 0), app: "x"))   // too old
        let report = WeekReport.make(now: now, calendar: ny, sessions: [], events: events)
        XCTAssertEqual(report.reaches.now, 9)
        XCTAssertEqual(report.topApp, WeekReport.Top(key: "instagram", count: 6))
        XCTAssertEqual(report.topHourValue, 22)

        let insight = WeekInsightEngine.make(report: report, appName: { $0 == "instagram" ? "Instagram" : $0 }, calendar: ny)
        XCTAssertEqual(insight.action, .remind(hour: 21, minute: 45, appID: "instagram"))
        XCTAssertEqual(plain(insight.text), "You reach for Instagram most around 10 PM. Set a 9:45 PM prayer reminder?")
        XCTAssertEqual(insight.actionTitle, "Set reminder")

        // Once that reminder is on, the insight moves on to something else.
        let next = WeekInsightEngine.make(report: report, appName: { $0 }, calendar: ny, nudge: (hour: 21, minute: 45))
        XCTAssertNotEqual(next.action, insight.action)
    }

    func testTooFewReachesNameNoPattern() {
        let now = TestCalendar.date(2026, 11, 18, 23, 0)
        let events = [ActivityEvent(kind: .reach, at: TestCalendar.date(2026, 11, 18, 22, 0), app: "instagram"),
                      ActivityEvent(kind: .reach, at: TestCalendar.date(2026, 11, 17, 22, 0), app: "instagram")]
        let report = WeekReport.make(now: now, calendar: ny, sessions: [prayer(now)], events: events)
        XCTAssertNil(report.topApp)
        XCTAssertNil(report.topHour)
    }

    func testReminderTimeIsAQuarterHourBeforeTheHour() {
        XCTAssertTrue(WeekInsightEngine.reminderTime(beforeHour: 22) == (21, 45))
        XCTAssertTrue(WeekInsightEngine.reminderTime(beforeHour: 0) == (23, 45), "midnight → 11:45 PM")
        XCTAssertTrue(WeekInsightEngine.reminderTime(beforeHour: 7) == (6, 45))
        XCTAssertEqual(plain(WeekInsightEngine.timeText(hour: 0, calendar: ny)), "12 AM")
        XCTAssertEqual(plain(WeekInsightEngine.timeText(hour: 23, minute: 45, calendar: ny)), "11:45 PM")
    }

    func testTheMoodThatCameUpMostPicksThePrayer() {
        let now = TestCalendar.date(2026, 11, 18, 12, 0)
        let events = [
            ActivityEvent(kind: .mood, at: TestCalendar.date(2026, 11, 17, 8, 0), detail: "anxious"),
            ActivityEvent(kind: .mood, at: TestCalendar.date(2026, 11, 16, 8, 0), detail: "anxious"),
            ActivityEvent(kind: .mood, at: TestCalendar.date(2026, 11, 15, 8, 0), detail: "grateful"),
            ActivityEvent(kind: .mood, at: TestCalendar.date(2026, 11, 15, 9, 0), detail: "not-a-mood"),
        ]
        let report = WeekReport.make(now: now, calendar: ny, sessions: [prayer(now)], events: events)
        XCTAssertEqual(report.topMood, .anxious)
        XCTAssertEqual(report.topMoodCount, 2)
        let insight = WeekInsightEngine.make(report: report, appName: { $0 }, calendar: ny)
        XCTAssertEqual(insight.action, .prayTopic(.anxiety))
    }

    func testInsightCopyIsWarm() {
        let now = TestCalendar.date(2026, 11, 18, 12, 0)
        let reports = [
            WeekReport.make(now: now, calendar: ny, sessions: []),
            WeekReport.make(now: now, calendar: ny, sessions: [prayer(TestCalendar.date(2026, 11, 8))]),
            WeekReport.make(now: now, calendar: ny, sessions: [prayer(now)]),
            WeekReport.make(now: now, calendar: ny, sessions: [prayer(now), prayer(now), prayer(TestCalendar.date(2026, 11, 8))]),
        ]
        for report in reports {
            let text = WeekInsightEngine.make(report: report, appName: { $0 }, calendar: ny).text.lowercased()
            for word in ["block", "fail", "shame", "lazy", "only ", "should"] {
                XCTAssertFalse(text.contains(word), "\(word) in \(text)")
            }
        }
    }
}
