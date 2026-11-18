// HOSTED-ONLY: drives the real AppModel (SwiftData + notifications + app host), so tools/run-unit-tests.sh skips this file.
#if STRICT_LOCK   // the Screen Time lock (project-strictlock.yml)
import SwiftUI
import XCTest
@testable import PrayToScroll

/// Strict Lock through AppModel, against a fake Screen Time that records every call. The pure decisions are in
/// ShieldPlannerTests; these check the wiring: lock → Amen → timer first, then open → relock, plus every escape.
final class LockLifecycleTests: XCTestCase {
    @MainActor
    private final class FakeLock: AppLock {
        var authorization: LockAuthorization = .approved
        var lockedCount = 3
        var shielded = false
        var scheduledRelock: Date?
        var refuseTimer = false
        var calls: [String] = []
        var reminder: Date?
        /// A reboot / iOS update / time-zone change made the running timer stale.
        var timerLost = false
        var isMonitoring: Bool { !timerLost && (scheduledRelock.map { $0 > Date() } ?? false) }
        var isShielded: Bool { shielded }

        func requestAuthorization() async -> LockAuthorization { authorization }
        func shield() { shielded = true; calls.append("shield") }
        func unshield() { shielded = false; calls.append("unshield") }
        func scheduleRelock(at end: Date, now: Date) throws {
            calls.append("schedule")
            if refuseTimer { throw NSError(domain: "DeviceActivity", code: 1) }
            scheduledRelock = end
            timerLost = false
        }
        func cancelRelock() { scheduledRelock = nil; calls.append("cancel") }
        func remindToRelock(at date: Date?) { reminder = date }
        func forgetSelection() { lockedCount = 0 }
        func icons(size: CGFloat, limit: Int) -> AnyView { AnyView(EmptyView()) }
        func picker(isPresented: Binding<Bool>, onChange: @escaping () -> Void) -> AnyView { AnyView(EmptyView()) }
    }

    @MainActor
    private func makeModel(_ configure: (inout AppSettings) -> Void = { _ in }) -> (AppModel, SharedStore, FakeLock) {
        let store = SharedStore(defaults: makeScratchDefaults())
        let lock = FakeLock()
        let model = AppModel(options: LaunchOptions(arguments: ["-demo"]), store: store, lock: lock)
        model.updateSettings {
            $0.lockMethod = .screenTime
            $0.unlockMode = .window
            $0.unlockWindowMinutes = 15
            configure(&$0)
        }
        model.syncLock()
        return (model, store, lock)
    }

    @MainActor
    @discardableResult
    private func pray(_ model: AppModel) -> PrayerCompletion {
        let now = Date()
        return model.completePrayer(PrayerOutcome(style: .quick, source: .gate, gatedAppID: AppLinks.screenTimeGateID,
                                                  startedAt: now.addingTimeInterval(-35), completedAt: now))
    }

    @MainActor
    func testLockedUntilAmenThenOpenWithATimerThenLockedAgain() throws {
        let (model, store, lock) = makeModel()
        XCTAssertTrue(model.usesScreenTime)
        XCTAssertTrue(lock.shielded, "the picked apps start locked")
        XCTAssertTrue(store.screenTimeActive)

        lock.calls = []
        let end = try XCTUnwrap(pray(model).unlockedUntil)
        XCTAssertEqual(end.timeIntervalSinceNow, 15 * 60, accuracy: 5)
        XCTAssertEqual(lock.scheduledRelock, end, "the relock timer ends with the window")
        XCTAssertFalse(lock.shielded)
        XCTAssertEqual(lock.calls, ["schedule", "unshield"], "the timer starts BEFORE the shield comes down")
        XCTAssertNil(model.lockFault)
        XCTAssertEqual(model.lockHealth(), .open(relocksAt: end), "Home's lock check: relock set")

        // Back in the app 5 minutes later: nothing restarts.
        lock.calls = []
        model.syncLock(now: Date().addingTimeInterval(5 * 60))
        XCTAssertEqual(lock.calls, ["unshield"])

        // The window is over (the monitor already relocked; the app agrees when it next opens).
        model.syncLock(now: end.addingTimeInterval(1))
        XCTAssertTrue(lock.shielded)
        XCTAssertNil(lock.scheduledRelock)
        XCTAssertEqual(model.lockHealth(now: end.addingTimeInterval(1)), .locked)
    }

    @MainActor
    func testLeavingTheAppLocksAWindowThatEndedWhileItWasOpen() throws {
        let (model, store, lock) = makeModel()
        pray(model)
        store.unlockedUntil = Date().addingTimeInterval(-1)   // the window ran out while Pray to Scroll was on screen
        model.sceneEnteredBackground()
        XCTAssertTrue(lock.shielded)
    }

    @MainActor
    func testAFiveMinuteWindowBecomesFifteenUnderScreenTime() throws {
        let (model, _, lock) = makeModel { $0.unlockWindowMinutes = 5 }
        XCTAssertEqual(model.effectiveWindowMinutes, 15)
        let end = try XCTUnwrap(pray(model).unlockedUntil)
        XCTAssertEqual(end.timeIntervalSinceNow, 15 * 60, accuracy: 5)
        XCTAssertEqual(lock.scheduledRelock, end)
    }

    @MainActor
    func testUnlockForUnderScreenTimeNeverGoesBelowFifteenAndRelocksAtTheEnd() throws {
        let (model, _, lock) = makeModel { UnlockChoice.minutes(5).apply(to: &$0) }
        XCTAssertEqual(model.minimumUnlockMinutes, 15)
        XCTAssertFalse(model.unlockPresets.contains(.minutes(5)), "5 min is Shortcuts only")
        XCTAssertEqual(model.unlockChoice, .minutes(15), "a 5-minute default from Shortcuts mode reads as 15")
        let end = try XCTUnwrap(pray(model).unlockedUntil)
        XCTAssertEqual(end.timeIntervalSinceNow, 15 * 60, accuracy: 5)
        XCTAssertEqual(lock.scheduledRelock, end, "DeviceActivity relocks when the window ends")

        model.updateSettings { UnlockChoice.minutes(120).apply(to: &$0) }
        let longer = try XCTUnwrap(pray(model).unlockedUntil)
        XCTAssertEqual(longer.timeIntervalSinceNow, 120 * 60, accuracy: 5)
        XCTAssertEqual(lock.scheduledRelock, longer)

        // Picked on the Amen screen: shorter than 15 still isn't possible, and the relock follows the pick.
        let picked = try XCTUnwrap(model.changeLastUnlock(to: .minutes(30)))
        XCTAssertEqual(picked.timeIntervalSinceNow, 30 * 60, accuracy: 5)
        XCTAssertEqual(lock.scheduledRelock, picked)
    }

    @MainActor
    func testATimerScreenTimeRefusesFailsOpenSaysLockPausedAndTapToFixRelocks() throws {
        let (model, store, lock) = makeModel()
        lock.refuseTimer = true
        let end = try XCTUnwrap(pray(model).unlockedUntil)
        XCTAssertFalse(lock.shielded, "fail open: the Amen still opens the apps")
        XCTAssertEqual(model.lockFault, .timerRefused, "never silent")
        XCTAssertEqual(store.lockFault, .timerRefused, "kept in the app group, so it survives the app being killed")
        XCTAssertEqual(model.lockHealth(), .paused(.timerRefused), "Home: Lock paused, tap to fix")
        XCTAssertEqual(lock.reminder, end, "a notification at the window's end")
        XCTAssertFalse(store.screenTimeActive, "a leftover Shortcuts automation guards the apps meanwhile")

        lock.refuseTimer = false
        model.retryLock()   // Fix
        XCTAssertFalse(lock.shielded)
        XCTAssertEqual(lock.scheduledRelock, end)
        XCTAssertNil(model.lockFault)
        XCTAssertEqual(model.lockHealth(), .open(relocksAt: end))
        XCTAssertTrue(store.screenTimeActive)
    }

    @MainActor
    func testAPausedLockWhoseWindowEndedLocksOnTheNextOpen() throws {
        let (model, store, lock) = makeModel()
        lock.refuseTimer = true
        let end = try XCTUnwrap(pray(model).unlockedUntil)
        lock.refuseTimer = false
        model.syncLock(now: end.addingTimeInterval(60))   // the reminder opened the app after the window
        XCTAssertTrue(lock.shielded)
        XCTAssertNil(model.lockFault)
        XCTAssertNil(store.lockFault)
    }

    @MainActor
    func testAFaultTheMonitorRecordedShowsOnHomeAndTheNextSyncFixesIt() throws {
        let (model, store, lock) = makeModel()
        model.pauseGate(days: 7)
        store.lockFault = .rearmFailed   // the extension couldn't start the pause's second leg
        lock.timerLost = true
        model.sceneBecameActive()
        XCTAssertNil(model.lockFault)
        XCTAssertNil(store.lockFault)
        XCTAssertFalse(lock.timerLost, "a new timer was started")
        XCTAssertEqual(lock.scheduledRelock, store.pausedUntil)
        XCTAssertFalse(lock.shielded, "still paused")
    }

    @MainActor
    func testAPausedLockIsReadFromTheAppGroupAtLaunch() {
        let store = SharedStore(defaults: makeScratchDefaults())
        store.lockFault = .rearmFailed
        let model = AppModel(options: LaunchOptions(arguments: ["-demo"]), store: store, lock: FakeLock())
        XCTAssertEqual(model.lockFault, .rearmFailed, "the monitor extension's fault shows on Home")
    }

    @MainActor
    func testALostTimerIsStartedAgainOnTheNextOpen() throws {
        let (model, _, lock) = makeModel()
        let end = try XCTUnwrap(pray(model).unlockedUntil)
        lock.timerLost = true   // a reboot, an iOS update or a time-zone change
        lock.calls = []
        model.sceneBecameActive()
        XCTAssertEqual(lock.calls, ["schedule", "unshield"])
        XCTAssertEqual(lock.scheduledRelock, end)
        XCTAssertEqual(model.lockHealth(), .open(relocksAt: end))
    }

    @MainActor
    func testTheEmergencyPassOpensForFifteenMinutesWithATimer() throws {
        let (model, store, lock) = makeModel()
        XCTAssertEqual(model.emergencyMinutes, 15)
        XCTAssertTrue(model.useEmergencyPass(for: nil))
        let end = try XCTUnwrap(store.unlockedUntil)
        XCTAssertEqual(end.timeIntervalSinceNow, 15 * 60, accuracy: 5)
        XCTAssertEqual(lock.scheduledRelock, end)
        XCTAssertFalse(lock.shielded)
        XCTAssertFalse(model.useEmergencyPass(for: nil), "once a day")
    }

    @MainActor
    func testPauseOpensUntilItEndsAndResumeLocksAgain() throws {
        let (model, store, lock) = makeModel()
        model.pauseGate(days: 1)
        let until = try XCTUnwrap(store.pausedUntil)
        XCTAssertEqual(lock.scheduledRelock, until)
        XCTAssertFalse(lock.shielded)
        model.pauseGate(days: nil)
        XCTAssertTrue(lock.shielded)
        XCTAssertNil(lock.scheduledRelock)
    }

    @MainActor
    func testTheDailyKeyOpensUntilTheResetWithATimer() throws {
        let (model, store, lock) = makeModel { $0.unlockMode = .dailyKey }
        pray(model)
        let until = try XCTUnwrap(store.dailyKeyUntil)
        XCTAssertGreaterThanOrEqual(until.timeIntervalSinceNow, 15 * 60 - 5, "never shorter than Screen Time's minimum")
        XCTAssertEqual(lock.scheduledRelock, until)
        XCTAssertFalse(lock.shielded)
    }

    @MainActor
    func testWithoutScreenTimeAccessTheShortcutsGateTakesOver() {
        let (model, store, lock) = makeModel()
        lock.authorization = .denied
        model.syncLock()
        XCTAssertFalse(model.usesScreenTime)
        XCTAssertFalse(lock.shielded)
        XCTAssertFalse(store.screenTimeActive)
        XCTAssertTrue(model.screenTimeAccessLost, "Home: Screen Time access is off, not \"Choose the apps\"")
        XCTAssertEqual(model.lockHealth(), .accessOff)
        XCTAssertEqual(model.effectiveWindowMinutes, 15)
        XCTAssertEqual(GateEngine.decide(appID: "instagram", now: Date(), snapshot: store.gateSnapshot), .requirePrayer,
                       "the Shortcuts automation asks for the prayer again")
    }

    @MainActor
    func testScreenTimeAccessResetByAnIOSUpdateIsShownAndLocksAgainWhenItsBack() {
        let (model, _, lock) = makeModel()
        XCTAssertTrue(lock.shielded)
        lock.authorization = .notDetermined   // an iOS update asked again
        model.syncLock()
        XCTAssertFalse(lock.shielded, "never stuck locked")
        XCTAssertTrue(model.screenTimeAccessLost)
        lock.authorization = .approved
        model.syncLock()
        XCTAssertTrue(lock.shielded)
        XCTAssertFalse(model.screenTimeAccessLost)
        XCTAssertEqual(model.lockHealth(), .locked)
    }

    @MainActor
    func testANewUserWhoNeverAllowedScreenTimeIsNotToldItWasTurnedOff() {
        let store = SharedStore(defaults: makeScratchDefaults())
        let lock = FakeLock()
        lock.authorization = .notDetermined
        let model = AppModel(options: LaunchOptions(arguments: ["-demo"]), store: store, lock: lock)
        model.updateSettings { $0.lockMethod = .screenTime }
        XCTAssertFalse(model.screenTimeAccessLost)
    }

    @MainActor
    func testTurningTheGateOffLiftsTheShield() {
        let (model, _, lock) = makeModel()
        XCTAssertTrue(lock.shielded)
        model.updateSettings { $0.gateEnabled = false }
        XCTAssertFalse(lock.shielded)
        XCTAssertNil(lock.scheduledRelock)
    }

    @MainActor
    func testPickingAppsSwitchesToScreenTime() {
        let (model, _, lock) = makeModel { $0.lockMethod = .shortcuts }
        XCTAssertFalse(lock.shielded)
        model.lockSelectionChanged()
        XCTAssertEqual(model.settings.lockMethod, .screenTime)
        XCTAssertTrue(lock.shielded)
        lock.lockedCount = 0
        model.lockSelectionChanged()
        XCTAssertFalse(model.usesScreenTime, "nothing picked, nothing locked")
        XCTAssertFalse(lock.shielded)
    }

    @MainActor
    func testEraseEverythingLiftsTheShield() {
        let (model, store, lock) = makeModel()
        XCTAssertTrue(lock.shielded)
        model.resetAllData()
        XCTAssertFalse(lock.shielded)
        XCTAssertNil(lock.scheduledRelock)
        XCTAssertFalse(store.screenTimeActive)
        XCTAssertEqual(lock.lockedCount, 0, "the picked apps are forgotten too")
        XCTAssertNil(lock.reminder)
        XCTAssertNil(model.lockFault)
    }
}
#endif
