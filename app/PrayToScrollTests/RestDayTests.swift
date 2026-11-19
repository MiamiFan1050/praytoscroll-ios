import XCTest
@testable import PrayToScroll

/// Sabbath rest day: it keeps the streak without adding to it or using the week's grace day, it only starts tomorrow,
/// and there's never more than one in 7 days, so switching the weekday can't turn missed days into rest.
final class RestDayTests: XCTestCase {
    let cal = TestCalendar.newYork
    // Nov 2026: Sun 15, Mon 16, Tue 17, Wed 18, Thu 19, Sat 21, Sun 22.
    func day(_ d: Int) -> DayKey { TestCalendar.day(2026, 11, d) }

    func testTheChosenWeekdayRepeatsFromItsStart() {
        let sundays = [RestPeriod(weekday: 1, from: day(10), through: nil)]
        XCTAssertEqual(RestDays.days(sundays, through: day(30), calendar: cal), [day(15), day(22), day(29)])
        XCTAssertEqual(RestDays.days(sundays, through: day(14), calendar: cal), [], "nothing before it starts")
        let ended = [RestPeriod(weekday: 1, from: day(10), through: day(20))]
        XCTAssertEqual(RestDays.days(ended, through: day(30), calendar: cal), [day(15)])
    }

    func testNeverTwoRestDaysWithinAWeek() {
        let switched = [RestPeriod(weekday: 1, from: day(1), through: day(18)), RestPeriod(weekday: 7, from: day(19), through: nil)]
        XCTAssertEqual(RestDays.days(switched, through: day(30), calendar: cal), [day(1), day(8), day(15), day(28)],
                       "Saturday the 21st is 6 days after Sunday the 15th")
        // Switching every day to "tomorrow" can't make a run of rest days.
        let daily = (19...24).map { RestPeriod(weekday: cal.component(.weekday, from: day($0).startDate(in: cal)), from: day($0), through: day($0)) }
        XCTAssertEqual(RestDays.days(daily, through: day(30), calendar: cal), [day(19)])
    }

    func testChoosingStartsTomorrowAndKeepsThePast() {
        var periods = RestDays.choosing(1, in: [], today: day(19), calendar: cal)
        XCTAssertEqual(periods, [RestPeriod(weekday: 1, from: day(20), through: nil)])
        XCTAssertEqual(RestDays.current(periods), 1)
        XCTAssertEqual(RestDays.choosing(1, in: periods, today: day(19), calendar: cal), periods, "same choice, no change")
        periods = RestDays.choosing(7, in: periods, today: day(19), calendar: cal)
        XCTAssertEqual(periods, [RestPeriod(weekday: 7, from: day(20), through: nil)], "changed the same day: replaced")
        periods = RestDays.choosing(nil, in: periods, today: day(25), calendar: cal)
        XCTAssertEqual(periods, [RestPeriod(weekday: 7, from: day(20), through: day(25))], "turned off: the past stays")
        XCTAssertNil(RestDays.current(periods))
        XCTAssertEqual(RestDays.days(periods, through: day(30), calendar: cal), [day(21)])
    }

    func testARestDayKeepsTheStreakWithoutCountingOrUsingGrace() {
        let prayed = Set((9...14).map(day)).union((16...18).map(day))   // Sunday the 15th rested
        let rest: Set<DayKey> = [day(15)]
        let frozen = StreakEngine.reconcileFreezes(prayed: prayed, frozen: [], rest: rest, today: day(19), calendar: cal)
        XCTAssertEqual(frozen, [], "no grace day spent")
        let summary = StreakEngine.summary(prayed: prayed, frozen: frozen, rest: rest, today: day(19), calendar: cal)
        XCTAssertEqual(summary.current, 9, "rest isn't counted, but it doesn't break the chain")
        XCTAssertTrue(summary.freezeAvailableThisWeek)
        XCTAssertTrue(summary.atRisk)
        XCTAssertEqual(StreakEngine.longestChain(prayed: prayed, frozen: [], rest: rest, calendar: cal), 9)
        XCTAssertEqual(StreakEngine.longestChain(prayed: prayed, frozen: [], calendar: cal), 6, "without it, two chains")
    }

    func testNothingIsAtRiskOnTheRestDay() {
        let prayed = Set((16...21).map(day))
        let summary = StreakEngine.summary(prayed: prayed, frozen: [], rest: [day(22)], today: day(22), calendar: cal)
        XCTAssertTrue(summary.isRestDay)
        XCTAssertFalse(summary.atRisk)
        XCTAssertEqual(summary.current, 6)
        let prayedToo = StreakEngine.summary(prayed: prayed.union([day(22)]), frozen: [], rest: [day(22)], today: day(22), calendar: cal)
        XCTAssertEqual(prayedToo.current, 7, "praying on a rest day still counts")
    }

    func testTheGraceDayStillCoversAMissedDayAfterRest() {
        let prayed = Set((9...14).map(day))
        let frozen = StreakEngine.reconcileFreezes(prayed: prayed, frozen: [], rest: [day(15)], today: day(17), calendar: cal)
        XCTAssertEqual(frozen, [day(16)])
        XCTAssertEqual(StreakEngine.summary(prayed: prayed, frozen: frozen, rest: [day(15)], today: day(17), calendar: cal).current, 6)
    }

    func testRestDaysAloneNeverSpendAGraceDay() {
        let rest: Set<DayKey> = [day(1), day(8), day(15)]
        let frozen = StreakEngine.reconcileFreezes(prayed: [TestCalendar.day(2026, 10, 1)], frozen: [], rest: rest, today: day(17), calendar: cal)
        XCTAssertEqual(frozen, [])
        XCTAssertEqual(StreakEngine.summary(prayed: [], frozen: [], rest: rest, today: day(17), calendar: cal).current, 0)
    }

    func testOlderSettingsHaveNoRestDay() throws {
        let old = try JSONDecoder().decode(AppSettings.self, from: Data(#"{"firstName":"Sam"}"#.utf8))
        XCTAssertEqual(old.restPeriods, [])
        var on = AppSettings()
        on.restPeriods = [RestPeriod(weekday: 1, from: day(20), through: nil)]
        XCTAssertEqual(try JSONDecoder().decode(AppSettings.self, from: JSONEncoder().encode(on)).restPeriods, on.restPeriods)
    }
}
