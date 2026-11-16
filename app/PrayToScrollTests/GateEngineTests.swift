import XCTest
@testable import PrayToScroll

final class GateEngineTests: XCTestCase {
    private let cal = TestCalendar.newYork

    private func snapshot(gated: Set<String> = ["instagram", "tiktok", "x"], unlockedUntil: Date? = nil) -> GateSnapshot {
        GateSnapshot(gateEnabled: true, gatedAppIDs: gated, customApps: [], unlockedUntil: unlockedUntil,
                     pausedUntil: nil, dailyKeyUntil: nil)
    }

    func testLockedAppRequiresPrayer() {
        let now = TestCalendar.date(2026, 11, 16, 9, 0)
        XCTAssertEqual(GateEngine.decide(appID: "instagram", now: now, snapshot: snapshot()), .requirePrayer)
    }

    func testUnlockedWindowLetsAppsThrough() {
        let now = TestCalendar.date(2026, 11, 16, 9, 0)
        let until = GateEngine.unlock(from: now, minutes: 15, existing: nil)
        XCTAssertEqual(until.timeIntervalSince(now), 15 * 60, accuracy: 0.001)
        let decision = GateEngine.decide(appID: "tiktok", now: now.addingTimeInterval(600), snapshot: snapshot(unlockedUntil: until))
        XCTAssertEqual(decision, .allow(until: until, reason: .unlocked))
    }

    func testUnlockWindowCrossesMidnight() {
        let now = TestCalendar.date(2026, 11, 16, 23, 55)
        let until = GateEngine.unlock(from: now, minutes: 15, existing: nil)
        XCTAssertEqual(DayKey(until, calendar: cal), TestCalendar.day(2026, 11, 17))
        let afterMidnight = TestCalendar.date(2026, 11, 17, 0, 5)
        XCTAssertEqual(GateEngine.decide(appID: "instagram", now: afterMidnight, snapshot: snapshot(unlockedUntil: until)),
                       .allow(until: until, reason: .unlocked))
        // 10 s after the window: grace. 30 s after: locked again.
        let grace = GateEngine.decide(appID: "instagram", now: until.addingTimeInterval(10), snapshot: snapshot(unlockedUntil: until))
        XCTAssertEqual(grace, .allow(until: until.addingTimeInterval(GateEngine.graceSeconds), reason: .grace))
        XCTAssertEqual(GateEngine.decide(appID: "instagram", now: until.addingTimeInterval(30), snapshot: snapshot(unlockedUntil: until)),
                       .requirePrayer)
    }

    func testUnlockNeverShortensAnExistingWindow() {
        let now = TestCalendar.date(2026, 11, 16, 9, 0)
        let long = GateEngine.unlock(from: now, minutes: 60, existing: nil)
        XCTAssertEqual(GateEngine.unlock(from: now, minutes: 5, existing: long), long)
        let short = GateEngine.unlock(from: now, minutes: 5, existing: nil)
        XCTAssertEqual(GateEngine.unlock(from: now, minutes: 30, existing: short), now.addingTimeInterval(30 * 60))
    }

    func testDailyKeyResetsAtTheResetHour() {
        let early = TestCalendar.date(2026, 11, 16, 2, 30)
        XCTAssertEqual(GateEngine.dailyKeyUntil(from: early, resetHour: 4, calendar: cal), TestCalendar.date(2026, 11, 16, 4, 0))
        let morning = TestCalendar.date(2026, 11, 16, 7, 0)
        XCTAssertEqual(GateEngine.dailyKeyUntil(from: morning, resetHour: 4, calendar: cal), TestCalendar.date(2026, 11, 17, 4, 0))
        var snap = snapshot()
        snap.dailyKeyUntil = TestCalendar.date(2026, 11, 17, 4, 0)
        XCTAssertEqual(GateEngine.decide(appID: "x", now: TestCalendar.date(2026, 11, 16, 22, 0), snapshot: snap),
                       .allow(until: snap.dailyKeyUntil, reason: .dailyKey))
        XCTAssertEqual(GateEngine.decide(appID: "x", now: TestCalendar.date(2026, 11, 17, 4, 1), snapshot: snap), .requirePrayer)
    }

    func testDailyKeyAcrossDaylightSavingEnd() {
        // DST ended 2026-11-01 at 2 AM in New York: the key still ends at 4 AM local time.
        let night = TestCalendar.date(2026, 10, 31, 23, 0)
        XCTAssertEqual(GateEngine.dailyKeyUntil(from: night, resetHour: 4, calendar: cal), TestCalendar.date(2026, 11, 1, 4, 0))
    }

    func testLaunchPassStopsTheGateLooping() {
        let now = TestCalendar.date(2026, 11, 16, 9, 0)
        var snap = snapshot()
        snap.launchPasses = ["instagram": now.addingTimeInterval(GateEngine.launchPassSeconds)]
        XCTAssertEqual(GateEngine.decide(appID: "instagram", now: now.addingTimeInterval(5), snapshot: snap),
                       .allow(until: snap.launchPasses["instagram"], reason: .launchPass))
        XCTAssertEqual(GateEngine.decide(appID: "instagram", now: now.addingTimeInterval(31), snapshot: snap), .requirePrayer)
        // A pass for one app doesn't open another.
        XCTAssertEqual(GateEngine.decide(appID: "tiktok", now: now.addingTimeInterval(5), snapshot: snap), .requirePrayer)
    }

    func testPendingTestWinsEvenWhileUnlockedAndExpires() {
        let now = TestCalendar.date(2026, 11, 16, 9, 0)
        var snap = snapshot(unlockedUntil: now.addingTimeInterval(900))
        snap.testPending = ["instagram": now]
        XCTAssertEqual(GateEngine.decide(appID: "instagram", now: now.addingTimeInterval(10), snapshot: snap), .verifyTest)
        XCTAssertEqual(GateEngine.decide(appID: "instagram", now: now.addingTimeInterval(GateEngine.testWindowSeconds + 1), snapshot: snap),
                       .allow(until: snap.unlockedUntil, reason: .unlocked))
        // Works even when the gate is switched off (people test during setup).
        snap.gateEnabled = false
        XCTAssertEqual(GateEngine.decide(appID: "instagram", now: now.addingTimeInterval(10), snapshot: snap), .verifyTest)
    }

    func testOneAutomationForAllAppsUsesTheSameRules() {
        let now = TestCalendar.date(2026, 11, 16, 9, 0)
        let any = GateEngine.anyAppID
        var snap = snapshot()
        XCTAssertEqual(GateEngine.canonicalID("app", customApps: []), any)
        XCTAssertEqual(GateEngine.decide(appID: any, now: now, snapshot: snap), .requirePrayer, "locked: pray first")
        snap.unlockedUntil = now.addingTimeInterval(900)
        XCTAssertEqual(GateEngine.decide(appID: any, now: now.addingTimeInterval(60), snapshot: snap),
                       .allow(until: snap.unlockedUntil, reason: .unlocked), "one window opens every app")
        snap.unlockedUntil = nil
        snap.launchPasses = ["tiktok": now.addingTimeInterval(GateEngine.launchPassSeconds)]
        XCTAssertEqual(GateEngine.decide(appID: any, now: now.addingTimeInterval(5), snapshot: snap),
                       .allow(until: snap.launchPasses["tiktok"], reason: .launchPass),
                       "reopening TikTok after the Amen doesn't loop, even though the automation can't say it's TikTok")
        XCTAssertEqual(GateEngine.decide(appID: any, now: now.addingTimeInterval(31), snapshot: snap), .requirePrayer)
        snap.gateEnabled = false
        XCTAssertEqual(GateEngine.decide(appID: any, now: now, snapshot: snap), .allow(until: nil, reason: .gateOff))
    }

    func testOneAutomationAnswersWhicheverAppIsBeingTested() {
        let now = TestCalendar.date(2026, 11, 16, 9, 0)
        var snap = snapshot()
        snap.testPending = ["instagram": now.addingTimeInterval(-30), "tiktok": now.addingTimeInterval(-5)]
        XCTAssertEqual(GateEngine.decide(appID: GateEngine.anyAppID, now: now, snapshot: snap), .verifyTest)
        XCTAssertEqual(GateEngine.testedApp(GateEngine.anyAppID, now: now, snapshot: snap), "tiktok", "the most recent test")
        XCTAssertEqual(GateEngine.testedApp("instagram", now: now, snapshot: snap), "instagram")
        XCTAssertNil(GateEngine.testedApp("x", now: now, snapshot: snap))
        XCTAssertNil(GateEngine.testedApp(GateEngine.anyAppID, now: now.addingTimeInterval(GateEngine.testWindowSeconds), snapshot: snap),
                     "old tests don't count")
    }

    func testGateOffAndPause() {
        let now = TestCalendar.date(2026, 11, 16, 9, 0)
        var snap = snapshot()
        snap.gateEnabled = false
        XCTAssertEqual(GateEngine.decide(appID: "instagram", now: now, snapshot: snap), .allow(until: nil, reason: .gateOff))
        snap.gateEnabled = true
        snap.pausedUntil = now.addingTimeInterval(3 * 86_400)
        XCTAssertEqual(GateEngine.decide(appID: "instagram", now: now, snapshot: snap), .allow(until: snap.pausedUntil, reason: .paused))
        XCTAssertEqual(GateEngine.decide(appID: "instagram", now: now.addingTimeInterval(3 * 86_400 + 1), snapshot: snap), .requirePrayer)
    }

    func testRemovedKnownAppPassesButUnknownAppsAreGated() {
        let now = TestCalendar.date(2026, 11, 16, 9, 0)
        XCTAssertEqual(GateEngine.decide(appID: "youtube", now: now, snapshot: snapshot()), .allow(until: nil, reason: .notGated))
        XCTAssertEqual(GateEngine.decide(appID: "some-game", now: now, snapshot: snapshot()), .requirePrayer)
    }

    func testAliasesShareTheSameGateState() {
        let now = TestCalendar.date(2026, 11, 16, 9, 0)
        XCTAssertEqual(GateEngine.canonicalID("Twitter", customApps: []), "x")
        XCTAssertEqual(GateEngine.canonicalID("fb", customApps: []), "facebook")
        var snap = snapshot()
        snap.launchPasses = ["x": now.addingTimeInterval(30)]
        XCTAssertEqual(GateEngine.decide(appID: "twitter", now: now, snapshot: snap), .allow(until: snap.launchPasses["x"], reason: .launchPass))
    }

    func testEmergencyPassIsOncePerCalendarDay() {
        let used = TestCalendar.date(2026, 11, 16, 8, 0)
        XCTAssertTrue(GateEngine.canUseEmergencyPass(now: used, lastUsed: nil, calendar: cal))
        XCTAssertFalse(GateEngine.canUseEmergencyPass(now: TestCalendar.date(2026, 11, 16, 23, 59), lastUsed: used, calendar: cal))
        XCTAssertTrue(GateEngine.canUseEmergencyPass(now: TestCalendar.date(2026, 11, 17, 0, 1), lastUsed: used, calendar: cal))
        XCTAssertEqual(GateEngine.nextEmergencyPassDate(now: TestCalendar.date(2026, 11, 16, 12, 0), lastUsed: used, calendar: cal),
                       TestCalendar.date(2026, 11, 17, 0, 0))
    }

    func testCountdownText() {
        XCTAssertEqual(GateEngine.countdownText(0), "0:00")
        XCTAssertEqual(GateEngine.countdownText(59.2), "1:00")
        XCTAssertEqual(GateEngine.countdownText(14 * 60 + 5), "14:05")
        XCTAssertEqual(GateEngine.countdownText(3600 + 61), "1:01:01")
        XCTAssertEqual(GateEngine.countdownText(-5), "0:00")
    }

    func testSetupStatus() {
        let now = TestCalendar.date(2026, 11, 16, 9, 0)
        XCTAssertEqual(GateSetupStatus.status(lastFired: nil, markedSetUpAt: nil, now: now), .notSetUp)
        XCTAssertEqual(GateSetupStatus.status(lastFired: nil, markedSetUpAt: now, now: now), .waitingForFirstOpen)
        let recent = now.addingTimeInterval(-3600)
        XCTAssertEqual(GateSetupStatus.status(lastFired: recent, markedSetUpAt: nil, now: now), .protected(lastFired: recent))
        let old = now.addingTimeInterval(-4 * 86_400)
        XCTAssertEqual(GateSetupStatus.status(lastFired: old, markedSetUpAt: nil, now: now), .silent(lastFired: old))
        XCTAssertFalse(GateSetupStatus.silent(lastFired: old).isProtected)
    }
}
