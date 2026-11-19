import XCTest
@testable import PrayToScroll

/// "I prayed offline yesterday": only yesterday, only when it keeps a streak, twice a month, never minutes.
final class OfflineGraceTests: XCTestCase {
    let cal = TestCalendar.newYork
    let today = TestCalendar.day(2026, 11, 19)

    func testOffersYesterdayWhenItKeepsTheStreak() {
        let prayed = TestCalendar.days(count: 5, endingAt: TestCalendar.day(2026, 11, 17))   // 13…17, missed the 18th
        XCTAssertEqual(OfflineGrace.offer(prayed: prayed, bridged: [], offline: [], today: today, calendar: cal),
                       TestCalendar.day(2026, 11, 18))
        // Once yesterday counts, the streak runs through it.
        let summary = StreakEngine.summary(prayed: prayed.union([TestCalendar.day(2026, 11, 18)]), frozen: [], today: today, calendar: cal)
        XCTAssertEqual(summary.current, 6)
    }

    func testNotOfferedWhenYesterdayIsPrayedOrThereIsNothingToKeep() {
        let prayedYesterday = TestCalendar.days(count: 3, endingAt: TestCalendar.day(2026, 11, 18))
        XCTAssertNil(OfflineGrace.offer(prayed: prayedYesterday, bridged: [], offline: [], today: today, calendar: cal))
        XCTAssertNil(OfflineGrace.offer(prayed: [], bridged: [], offline: [], today: today, calendar: cal), "no streak to keep")
        let longAgo: Set<DayKey> = [TestCalendar.day(2026, 11, 10)]
        XCTAssertNil(OfflineGrace.offer(prayed: longAgo, bridged: [], offline: [], today: today, calendar: cal), "only yesterday, never older")
    }

    func testAGraceDayOrRestDayBeforeYesterdayStillLinks() {
        let prayed: Set<DayKey> = [TestCalendar.day(2026, 11, 16)]
        let bridged: Set<DayKey> = [TestCalendar.day(2026, 11, 17)]
        XCTAssertEqual(OfflineGrace.offer(prayed: prayed, bridged: bridged, offline: [], today: today, calendar: cal),
                       TestCalendar.day(2026, 11, 18))
    }

    func testAtMostTwiceInACalendarMonth() {
        let prayed: Set<DayKey> = [TestCalendar.day(2026, 11, 17)]
        let twice = [TestCalendar.day(2026, 11, 3), TestCalendar.day(2026, 11, 9)]
        XCTAssertEqual(OfflineGrace.remaining(inMonthOf: TestCalendar.day(2026, 11, 18), offline: twice), 0)
        XCTAssertNil(OfflineGrace.offer(prayed: prayed, bridged: [], offline: twice, today: today, calendar: cal))
        XCTAssertEqual(OfflineGrace.remaining(inMonthOf: TestCalendar.day(2026, 11, 18), offline: [TestCalendar.day(2026, 11, 3)]), 1)
        // A new month starts fresh, and yesterday's month is the one that counts (on Dec 1, yesterday is Nov 30).
        let dec1 = TestCalendar.day(2026, 12, 1)
        XCTAssertNil(OfflineGrace.offer(prayed: [TestCalendar.day(2026, 11, 29)], bridged: [], offline: twice, today: dec1, calendar: cal))
        XCTAssertEqual(OfflineGrace.offer(prayed: [TestCalendar.day(2026, 12, 1)], bridged: [], offline: twice,
                                          today: TestCalendar.day(2026, 12, 3), calendar: cal),
                       TestCalendar.day(2026, 12, 2), "November's two don't count against December")
    }

    func testDuplicatesOfOneDayCountOnce() {
        let sameDay = [TestCalendar.day(2026, 11, 3), TestCalendar.day(2026, 11, 3)]
        XCTAssertEqual(OfflineGrace.used(inMonthOf: TestCalendar.day(2026, 11, 18), offline: sameDay), 1)
    }

    func testOfflineIsItsOwnStoredSource() {
        XCTAssertEqual(SessionSource.offline.rawValue, "offline")
        XCTAssertEqual(SessionSource(rawValue: "offline"), .offline)
    }
}
