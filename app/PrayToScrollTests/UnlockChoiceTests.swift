import XCTest
@testable import PrayToScroll

/// "Unlock for": every length, Custom, Rest of today, across midnight and daylight saving, and the migration.
final class UnlockChoiceTests: XCTestCase {
    private let calendar = TestCalendar.newYork
    private func at(_ y: Int, _ mo: Int, _ d: Int, _ h: Int, _ mi: Int = 0) -> Date { TestCalendar.date(y, mo, d, h, mi) }
    private func end(_ choice: UnlockChoice, _ now: Date, reset: Int = 4) -> Date {
        choice.end(from: now, resetHour: reset, calendar: calendar)
    }

    func testThePresetsOnOffer() {
        XCTAssertEqual(UnlockChoice.presets(minimumMinutes: 5),
                       [.minutes(5), .minutes(15), .minutes(30), .minutes(45), .minutes(60), .minutes(120), .minutes(180), .restOfToday])
        XCTAssertEqual(UnlockChoice.presets(minimumMinutes: 15).first, .minutes(15), "no 5 minutes under Screen Time")
        XCTAssertEqual(UnlockChoice.presets(minimumMinutes: 15).last, .restOfToday)
    }

    func testEveryPresetEndsExactlyThatLongAfterTheAmen() {
        let now = at(2026, 11, 16, 14, 7)
        for m in UnlockChoice.presetMinutes {
            XCTAssertEqual(end(.minutes(m), now).timeIntervalSince(now), Double(m * 60), "\(m) min")
        }
    }

    func testAWindowCrossesMidnightAsAnAbsoluteInstant() {
        let now = at(2026, 11, 16, 23, 30)
        XCTAssertEqual(end(.minutes(120), now), at(2026, 11, 17, 1, 30))
    }

    func testRestOfTodayEndsAtTheResetHour() {
        XCTAssertEqual(end(.restOfToday, at(2026, 11, 16, 9, 0)), at(2026, 11, 17, 4, 0), "a morning prayer lasts until 4 AM")
        XCTAssertEqual(end(.restOfToday, at(2026, 11, 16, 23, 59)), at(2026, 11, 17, 4, 0), "across midnight")
        XCTAssertEqual(end(.restOfToday, at(2026, 11, 17, 2, 0)), at(2026, 11, 17, 4, 0), "after midnight, before the reset")
        XCTAssertEqual(end(.restOfToday, at(2026, 11, 17, 4, 0)), at(2026, 11, 18, 4, 0), "at the reset, the next day's")
        XCTAssertEqual(end(.restOfToday, at(2026, 11, 16, 9, 0), reset: 6), at(2026, 11, 17, 6, 0), "the reset hour is a setting")
    }

    func testCustomIsFifteenMinutesToEightHoursInFiveMinuteSteps() {
        XCTAssertEqual(UnlockChoice.clampCustom(3), 15)
        XCTAssertEqual(UnlockChoice.clampCustom(92), 90)
        XCTAssertEqual(UnlockChoice.clampCustom(93), 95)
        XCTAssertEqual(UnlockChoice.clampCustom(600), 480)
        let now = at(2026, 11, 16, 10, 0)
        XCTAssertEqual(end(.custom(95), now).timeIntervalSince(now), 95 * 60)
        XCTAssertEqual(end(.custom(480), now).timeIntervalSince(now), 8 * 3600)
    }

    func testCustomNeverRunsPastTheNextReset() {
        XCTAssertEqual(end(.custom(480), at(2026, 11, 16, 22, 0)), at(2026, 11, 17, 4, 0), "8 h at 10 PM stops at 4 AM")
        XCTAssertEqual(end(.custom(60), at(2026, 11, 17, 3, 30)), at(2026, 11, 17, 4, 0))
        XCTAssertEqual(end(.custom(120), at(2026, 11, 17, 1, 0)), at(2026, 11, 17, 3, 0), "inside the day: the full length")
    }

    func testDaylightSavingEnd() {
        // Nov 1 2026, 2:00 AM EDT → 1:00 AM EST: that night has 25 hours.
        let evening = at(2026, 10, 31, 22, 0)
        let rest = end(.restOfToday, evening)
        XCTAssertEqual(rest, at(2026, 11, 1, 4, 0))
        XCTAssertEqual(rest.timeIntervalSince(evening), 7 * 3600, "an extra hour that night")
        XCTAssertEqual(end(.custom(480), evening), rest, "capped at the reset")
        XCTAssertEqual(end(.minutes(180), evening).timeIntervalSince(evening), 3 * 3600, "3 h is 3 real hours")
    }

    func testDaylightSavingStart() {
        // Mar 14 2027, 2:00 AM EST → 3:00 AM EDT: that night has 23 hours.
        let evening = at(2027, 3, 13, 23, 0)
        let rest = end(.restOfToday, evening)
        XCTAssertEqual(rest, at(2027, 3, 14, 4, 0))
        XCTAssertEqual(rest.timeIntervalSince(evening), 4 * 3600)
        let lateNight = at(2027, 3, 14, 1, 30)
        XCTAssertEqual(end(.minutes(60), lateNight), at(2027, 3, 14, 3, 30), "1 h across the skipped hour")
    }

    func testLabels() {
        XCTAssertEqual(UnlockChoice.minutes(45).title, "45 min")
        XCTAssertEqual(UnlockChoice.minutes(60).title, "1 h")
        XCTAssertEqual(UnlockChoice.custom(95).title, "1 h 35 min")
        XCTAssertEqual(UnlockChoice.restOfToday.title, "Rest of today")
        XCTAssertEqual(UnlockChoice.spoken(minutes: 60), "1 hour")
        XCTAssertEqual(UnlockChoice.spoken(minutes: 150), "2 hours 30 minutes")
    }

    func testMigrationDailyKeyBecomesRestOfTodayAndWindowsStay() throws {
        func decode(_ json: String) throws -> AppSettings { try JSONDecoder().decode(AppSettings.self, from: Data(json.utf8)) }
        XCTAssertEqual(UnlockChoice.current(in: try decode(#"{"unlockMode":"dailyKey","unlockWindowMinutes":15}"#)), .restOfToday)
        XCTAssertEqual(UnlockChoice.current(in: try decode(#"{"unlockMode":"window","unlockWindowMinutes":30}"#)), .minutes(30))
        XCTAssertEqual(UnlockChoice.current(in: try decode(#"{"unlockMode":"window","unlockWindowMinutes":5}"#)), .minutes(5))
        let old = try decode(#"{"unlockMode":"window","unlockWindowMinutes":60}"#)
        XCTAssertFalse(old.askUnlockEachTime, "off by default")
        XCTAssertFalse(old.unlockCustom)
        XCTAssertEqual(UnlockChoice.current(in: AppSettings()), .minutes(GateEngine.defaultWindowMinutes))
    }

    func testApplyRoundTrips() throws {
        for choice: UnlockChoice in [.minutes(5), .minutes(45), .minutes(180), .custom(95), .custom(480), .restOfToday] {
            var settings = AppSettings()
            choice.apply(to: &settings)
            let reloaded = try JSONDecoder().decode(AppSettings.self, from: JSONEncoder().encode(settings))
            XCTAssertEqual(UnlockChoice.current(in: reloaded), choice, choice.id)
        }
        var settings = AppSettings()
        UnlockChoice.restOfToday.apply(to: &settings)
        UnlockChoice.minutes(30).apply(to: &settings)
        XCTAssertEqual(settings.unlockMode, .window, "leaving Rest of today")
    }

    func testUnlockToAnInstantNeverShortensAnEarlierWindow() {
        let now = at(2026, 11, 16, 12, 0)
        XCTAssertEqual(GateEngine.unlock(from: now, until: now.addingTimeInterval(900), existing: now.addingTimeInterval(3600)),
                       now.addingTimeInterval(3600))
        XCTAssertEqual(GateEngine.unlock(from: now, until: now.addingTimeInterval(900), existing: nil), now.addingTimeInterval(900))
    }
}
