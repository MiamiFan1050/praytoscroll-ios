// HOSTED-ONLY: drives the real AppModel (SwiftData + app host), so tools/run-unit-tests.sh skips this file.
import SwiftData
import XCTest
@testable import PrayToScroll

/// Streak grace through the real AppModel: "I prayed offline yesterday" keeps the streak, adds no minutes or
/// prayers, and can't be used twice for one day.
final class StreakGraceHostedTests: XCTestCase {
    @MainActor
    func testPrayedOfflineYesterdayKeepsTheStreakWithNoMinutes() throws {
        let store = SharedStore(defaults: makeScratchDefaults())
        let model = AppModel(options: LaunchOptions(arguments: ["-demo", "-shortcutsGate"]), store: store)
        let calendar = Calendar.current
        let now = Date()
        let yesterday = DayKey(now, calendar: calendar).adding(days: -1, calendar: calendar)
        // The demo prayed every day but one of the last two weeks: take yesterday away.
        for session in model.allSessions() where DayKey(session.completedAt, calendar: calendar) == yesterday {
            model.context.delete(session)
        }
        try model.context.save()
        model.refreshStreak(now: now)
        XCTAssertEqual(model.offlineOffer(now: now), yesterday)

        let minutes = model.allSessions().reduce(0) { $0 + $1.durationSeconds }
        let inApp = model.allSessions().filter { $0.source != .offline }.count
        XCTAssertTrue(model.logOfflinePrayer(now: now))
        XCTAssertTrue(model.prayedDays.contains(yesterday))
        XCTAssertFalse(model.streak.frozenDays.contains(yesterday), "a grace day covering it is given back")
        XCTAssertGreaterThan(model.streak.current, 1)
        XCTAssertEqual(model.allSessions().reduce(0) { $0 + $1.durationSeconds }, minutes, "no minutes added")
        XCTAssertEqual(model.allSessions().filter { $0.source != .offline }.count, inApp, "not an in-app prayer")
        XCTAssertEqual(model.offlineDays(calendar: calendar), [yesterday])
        XCTAssertNil(model.offlineOffer(now: now), "once for a day")
        XCTAssertFalse(model.logOfflinePrayer(now: now))
    }
}
