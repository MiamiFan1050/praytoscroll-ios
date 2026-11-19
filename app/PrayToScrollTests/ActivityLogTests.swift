import XCTest
@testable import PrayToScroll

/// The local "Your week" log: put-it-down wins, gate reaches, and the rolling 7-day window they're counted in.
final class ActivityLogTests: XCTestCase {
    private let cal = TestCalendar.newYork

    private func makeLog() -> (ActivityLog, SharedStore) {
        let store = SharedStore(defaults: makeScratchDefaults())
        return (store.activity, store)
    }

    func testPutDownIsLoggedAndCountedThisWeek() {
        let (log, _) = makeLog()
        let now = TestCalendar.date(2026, 11, 18, 21, 30)
        let week = WeekWindow.current(now: now, calendar: cal)
        XCTAssertEqual(log.count(.putDown, in: week), 0, "nothing logged yet")

        log.record(.putDown, app: "instagram", at: TestCalendar.date(2026, 11, 16, 22, 5))
        log.record(.putDown, app: "tiktok", at: TestCalendar.date(2026, 11, 17, 13, 0))
        log.record(.putDown, app: "instagram", at: now)
        XCTAssertEqual(log.count(.putDown, in: week), 3)
        XCTAssertEqual(log.events(.putDown, in: week).map(\.app), ["instagram", "tiktok", "instagram"], "oldest first, with the app")
        XCTAssertEqual(log.count(.reach, in: week), 0, "kinds are counted apart")

        // Eight days later the first two have rolled out of the week.
        let later = TestCalendar.date(2026, 11, 24, 21, 0)
        XCTAssertEqual(log.count(.putDown, in: WeekWindow.current(now: later, calendar: cal)), 1)
        XCTAssertEqual(log.count(.putDown, in: WeekWindow.previous(now: later, calendar: cal)), 2)
    }

    func testPutDownCopyCountsTheRightWay() {
        XCTAssertEqual(PutDownCopy.countLine(1), "Your first time this week choosing not to scroll.")
        XCTAssertEqual(PutDownCopy.countLine(3), "That's the 3rd time this week you chose not to scroll.")
        XCTAssertEqual(["1", "2", "3", "4", "11", "12", "13", "21", "22", "23", "101", "111"].compactMap(Int.init).map(PutDownCopy.ordinal),
                       ["1st", "2nd", "3rd", "4th", "11th", "12th", "13th", "21st", "22nd", "23rd", "101st", "111th"])
        XCTAssertFalse(PutDownCopy.warmLine(for: 0).isEmpty)
        XCTAssertNotEqual(PutDownCopy.warmLine(for: 1), PutDownCopy.warmLine(for: 2), "the line changes as the count grows")
        for line in PutDownCopy.warmLines + [PutDownCopy.countLine(2)] {
            for word in ["block", "shame", "fail", "weak"] {
                XCTAssertFalse(line.lowercased().contains(word), "no \(word) in \(line)")
            }
        }
    }

    func testAReachIsLoggedOncePerAppPerMinute() {
        let (log, _) = makeLog()
        let t = TestCalendar.date(2026, 11, 18, 22, 0)
        XCTAssertTrue(log.record(.reach, app: "instagram", at: t))
        XCTAssertFalse(log.record(.reach, app: "instagram", at: t.addingTimeInterval(20)), "the same open firing twice")
        XCTAssertTrue(log.record(.reach, app: "tiktok", at: t.addingTimeInterval(20)), "another app counts")
        XCTAssertTrue(log.record(.reach, app: "instagram", at: t.addingTimeInterval(90)))
        XCTAssertTrue(log.record(.putDown, app: "instagram", at: t.addingTimeInterval(91)), "only reaches are de-duplicated")
        XCTAssertEqual(log.count(.reach, in: WeekWindow.current(now: t, calendar: cal)), 3)
    }

    func testOnlyRealOpensCountAsReaches() {
        let soon = Date().addingTimeInterval(600)
        XCTAssertTrue(GateDecision.requirePrayer.isReach, "the gate asked for a prayer")
        XCTAssertTrue(GateDecision.allow(until: soon, reason: .unlocked).isReach, "opened inside a window")
        XCTAssertTrue(GateDecision.allow(until: soon, reason: .dailyKey).isReach)
        for reason in [AllowReason.launchPass, .grace, .gateOff, .paused, .notGated] {
            XCTAssertFalse(GateDecision.allow(until: soon, reason: reason).isReach, "\(reason) isn't the person reaching")
        }
        XCTAssertFalse(GateDecision.verifyTest.isReach, "Test my gate")
    }

    func testOldEventsFallOffAndTheLogStaysSmall() {
        let (log, _) = makeLog()
        let now = TestCalendar.date(2026, 11, 18)
        log.record(.emergency, app: "x", at: now.addingTimeInterval(-70 * 86_400))
        log.record(.emergency, app: "x", at: now)
        XCTAssertEqual(log.events.count, 1, "events past \(Int(ActivityLog.keepDays)) days are trimmed on the next write")
        let full = (0..<ActivityLog.maxEvents).map { ActivityEvent(kind: .putDown, at: now.addingTimeInterval(Double($0))) }
        log.defaults.set(try? JSONEncoder().encode(full), forKey: ActivityLog.key)
        for i in ActivityLog.maxEvents..<(ActivityLog.maxEvents + 20) {
            log.record(.putDown, at: now.addingTimeInterval(Double(i)))
        }
        XCTAssertEqual(log.events.count, ActivityLog.maxEvents)
        XCTAssertEqual(log.events.last?.at, now.addingTimeInterval(Double(ActivityLog.maxEvents + 19)), "the newest are kept")
    }

    func testEraseAllDataClearsTheLog() {
        let (log, store) = makeLog()
        log.record(.putDown, app: "instagram", at: Date())
        XCTAssertEqual(log.events.count, 1)
        store.resetAll()
        XCTAssertTrue(store.activity.events.isEmpty, "the key is under ak., so Erase All Data removes it")
    }
}
