import XCTest
@testable import PrayToScroll

final class SharedStoreTests: XCTestCase {
    private var store: SharedStore!

    override func setUp() {
        super.setUp()
        store = SharedStore(defaults: makeScratchDefaults())
    }

    func testLaunchPassAndTestRequestFeedTheSnapshot() {
        let now = Date()
        store.grantLaunchPass(appID: "Twitter", now: now)
        store.startTest(appID: "instagram", now: now)
        let snap = store.gateSnapshot
        XCTAssertNotNil(snap.launchPasses["x"], "aliases are stored under the catalog id")
        XCTAssertNotNil(snap.testPending["instagram"])
        store.clearTest(appID: "instagram")
        XCTAssertNil(store.gateSnapshot.testPending["instagram"])
    }

    func testPendingGateIsConsumedOnce() {
        let now = Date()
        store.setPendingGate(appID: "tiktok", at: now)
        XCTAssertEqual(store.consumePendingGate(now: now.addingTimeInterval(2)), "tiktok")
        XCTAssertNil(store.consumePendingGate(now: now.addingTimeInterval(3)))
    }

    func testStreakSummaryReadsStoredDays() {
        let cal = TestCalendar.newYork
        let today = TestCalendar.day(2026, 11, 16)
        store.prayedDays = TestCalendar.days(count: 4, endingAt: today)
        let s = store.streakSummary(now: TestCalendar.date(2026, 11, 16, 20, 0), calendar: cal)
        XCTAssertEqual(s.current, 4)
        XCTAssertTrue(s.prayedToday)
    }

    func testSettingsRoundTripAndResetAll() {
        var settings = store.settings
        settings.firstName = "Mark"
        settings.gateEnabled = true
        store.settings = settings
        XCTAssertEqual(store.settings.firstName, "Mark")
        store.unlockedUntil = Date().addingTimeInterval(600)
        let memberID = store.circleMemberID
        XCTAssertEqual(store.circleMemberID, memberID, "member id is stable")
        store.resetAll()
        XCTAssertNil(store.unlockedUntil)
        XCTAssertEqual(store.settings.firstName, AppSettings().firstName)
        XCTAssertNotEqual(store.circleMemberID, memberID, "erasing data rotates the anonymous id")
    }

    func testPromptBagPersistsInTheStore() {
        let pool = ["a", "b", "c"]
        let drawn = (0..<3).map { _ in store.nextPrompt(key: "test", from: pool) }
        XCTAssertEqual(Set(drawn), Set(pool))
        XCTAssertEqual(store.nextPrompt(key: "test", from: []), "")
    }
}
