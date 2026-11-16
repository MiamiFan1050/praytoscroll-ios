import XCTest
@testable import PrayToScroll

final class StreakTests: XCTestCase {
    private let cal = TestCalendar.newYork
    // 2026-11-16 is a Monday; with Monday-first weeks, Nov 9–15 is one week and Nov 16–22 the next.
    private let monday = TestCalendar.day(2026, 11, 16)

    func testConsecutiveDaysCount() {
        let prayed = TestCalendar.days(count: 5, endingAt: monday)
        let s = StreakEngine.summary(prayed: prayed, frozen: [], today: monday, calendar: cal)
        XCTAssertEqual(s.current, 5)
        XCTAssertEqual(s.longest, 5)
        XCTAssertTrue(s.prayedToday)
        XCTAssertFalse(s.atRisk)
        XCTAssertEqual(s.totalDaysPrayed, 5)
    }

    func testStreakStaysAliveUntilTheDayEnds() {
        let yesterday = monday.adding(days: -1, calendar: cal)
        let prayed = TestCalendar.days(count: 3, endingAt: yesterday)
        let s = StreakEngine.summary(prayed: prayed, frozen: [], today: monday, calendar: cal)
        XCTAssertEqual(s.current, 3)
        XCTAssertFalse(s.prayedToday)
        XCTAssertTrue(s.atRisk)
    }

    func testOneMissedDayIsCoveredByTheFreeFreeze() {
        // Prayed Thu 12 – Sat 14, missed Sun 15, opening the app Mon 16.
        let prayed = TestCalendar.days(count: 3, endingAt: TestCalendar.day(2026, 11, 14))
        let frozen = StreakEngine.reconcileFreezes(prayed: prayed, frozen: [], today: monday, calendar: cal)
        XCTAssertEqual(frozen, [TestCalendar.day(2026, 11, 15)])
        let s = StreakEngine.summary(prayed: prayed, frozen: frozen, today: monday, calendar: cal)
        XCTAssertEqual(s.current, 3, "frozen days keep the chain but don't add to it")
        XCTAssertTrue(s.atRisk)
        XCTAssertTrue(s.freezeAvailableThisWeek, "Monday starts a new week with a new freeze")
        let afterPraying = StreakEngine.summary(prayed: prayed.union([monday]), frozen: frozen, today: monday, calendar: cal)
        XCTAssertEqual(afterPraying.current, 4)
    }

    func testTwoMissedDaysInOneWeekBreakTheStreakWithoutBurningTheFreeze() {
        // Prayed Mon 9 – Thu 12, missed Fri 13 + Sat 14 (same week), today Sun 15.
        let today = TestCalendar.day(2026, 11, 15)
        let prayed = TestCalendar.days(count: 4, endingAt: TestCalendar.day(2026, 11, 12))
        let frozen = StreakEngine.reconcileFreezes(prayed: prayed, frozen: [], today: today, calendar: cal)
        XCTAssertTrue(frozen.isEmpty)
        let s = StreakEngine.summary(prayed: prayed, frozen: frozen, today: today, calendar: cal)
        XCTAssertEqual(s.current, 0)
        XCTAssertEqual(s.longest, 4)
        XCTAssertFalse(s.atRisk)
    }

    func testMissedDaysAcrossTwoWeeksUseOneFreezeEach() {
        // Prayed through Sat 14, missed Sun 15 (week 1) and Mon 16 (week 2), today Tue 17.
        let today = TestCalendar.day(2026, 11, 17)
        let prayed = TestCalendar.days(count: 6, endingAt: TestCalendar.day(2026, 11, 14))
        let frozen = StreakEngine.reconcileFreezes(prayed: prayed, frozen: [], today: today, calendar: cal)
        XCTAssertEqual(frozen, [TestCalendar.day(2026, 11, 15), TestCalendar.day(2026, 11, 16)])
        let s = StreakEngine.summary(prayed: prayed, frozen: frozen, today: today, calendar: cal)
        XCTAssertEqual(s.current, 6)
        XCTAssertFalse(s.freezeAvailableThisWeek)
    }

    func testAFreezeAlreadyUsedThisWeekCantBeUsedAgain() {
        let today = TestCalendar.day(2026, 11, 15)
        let used: Set<DayKey> = [TestCalendar.day(2026, 11, 10)]
        let prayed: Set<DayKey> = [TestCalendar.day(2026, 11, 9), TestCalendar.day(2026, 11, 11), TestCalendar.day(2026, 11, 12),
                                   TestCalendar.day(2026, 11, 13)]
        let frozen = StreakEngine.reconcileFreezes(prayed: prayed, frozen: used, today: today, calendar: cal)
        XCTAssertEqual(frozen, used, "Sat 14 can't be frozen: this week's freeze went to Tue 10")
        XCTAssertEqual(StreakEngine.summary(prayed: prayed, frozen: frozen, today: today, calendar: cal).current, 0)
    }

    func testLongGapsNeverSpendFreezes() {
        let today = TestCalendar.day(2026, 11, 16)
        let prayed: Set<DayKey> = [TestCalendar.day(2026, 10, 1)]
        XCTAssertTrue(StreakEngine.reconcileFreezes(prayed: prayed, frozen: [], today: today, calendar: cal).isEmpty)
    }

    func testLongestChainIgnoresFrozenDaysInTheCount() {
        let prayed: Set<DayKey> = [TestCalendar.day(2026, 11, 1), TestCalendar.day(2026, 11, 2), TestCalendar.day(2026, 11, 4),
                                   TestCalendar.day(2026, 11, 10)]
        let frozen: Set<DayKey> = [TestCalendar.day(2026, 11, 3)]
        XCTAssertEqual(StreakEngine.longestChain(prayed: prayed, frozen: frozen, calendar: cal), 3)
        XCTAssertEqual(StreakEngine.longestChain(prayed: [], frozen: [], calendar: cal), 0)
    }

    func testMilestones() {
        XCTAssertEqual(MilestoneEngine.newlyEarned(streak: 7, alreadyAwarded: [3]), [7])
        XCTAssertEqual(MilestoneEngine.newlyEarned(streak: 2, alreadyAwarded: []), [])
        XCTAssertEqual(MilestoneEngine.newlyEarned(streak: 30, alreadyAwarded: [3, 7, 14]), [21, 30])
        XCTAssertEqual(MilestoneEngine.next(after: 7), 14)
        XCTAssertNil(MilestoneEngine.next(after: 365))
        for m in MilestoneEngine.milestones {
            XCTAssertFalse(MilestoneEngine.title(for: m).isEmpty)
            XCTAssertFalse(MilestoneEngine.symbol(for: m).isEmpty)
        }
    }

    func testDayKeyRoundTripsAndCountsAcrossDST() {
        let day = TestCalendar.day(2026, 10, 31)
        XCTAssertEqual(DayKey(string: day.string), day)
        XCTAssertNil(DayKey(string: "2026-13-01"))
        XCTAssertEqual(day.adding(days: 2, calendar: cal), TestCalendar.day(2026, 11, 2))
        XCTAssertEqual(day.days(until: TestCalendar.day(2026, 11, 7), calendar: cal), 7)
        XCTAssertEqual(DayKey(TestCalendar.date(2026, 11, 16, 23, 59), calendar: cal), monday)
    }
}
