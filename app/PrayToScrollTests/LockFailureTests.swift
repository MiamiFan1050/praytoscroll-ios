// STRICT_LOCK-ONLY: the Screen Time lock's failure paths (project-strictlock.yml); STRICT_LOCK=1 tools/run-unit-tests.sh runs it.
#if STRICT_LOCK
import XCTest
@testable import PrayToScroll

/// Every way Strict Lock could end up "stuck locked" or "never locks again", on a simulated iPhone that follows
/// Apple's DeviceActivity rules (SimulatedPhone). The app side is the real RelockEngine.sync (AppModel.syncLock), the
/// monitor the real RelockEngine.monitorFired (DeviceActivityMonitorExtension).
final class LockFailureTests: XCTestCase {
    private let t0 = TestCalendar.date(2026, 11, 17, 9, 0)

    private func phone(zone: String = "America/New_York") -> SimulatedPhone {
        let phone = SimulatedPhone(now: t0, zone: zone)
        phone.appSync()
        return phone
    }

    // MARK: After an Amen: open for the chosen length, then locked again on time (Mark's "it never locks again")

    func testAnAmenOpensForTheChosenLengthThenTheAppsLockAgainOnTimeByThemselves() throws {
        for minutes in [15, 30, 45, 60, 120, 180] {
            let phone = phone()
            XCTAssertTrue(phone.shielded, "locked before the Amen")
            let until = phone.amen(minutes: minutes)
            XCTAssertEqual(until.timeIntervalSince(t0), Double(minutes) * 60, accuracy: 0.5)
            XCTAssertFalse(phone.shielded, "\(minutes) min: open after the Amen")
            XCTAssertEqual(phone.health, .open(relocksAt: until), "Home's lock check: relock set")
            XCTAssertEqual(phone.reminder, until.addingTimeInterval(ShieldPlanner.safetyReminderDelay), "the safety net is set")

            phone.advance(to: until.addingTimeInterval(-1))
            XCTAssertFalse(phone.shielded, "\(minutes) min: still open a second before the end")
            phone.advance(to: until.addingTimeInterval(1))
            XCTAssertTrue(phone.shielded, "\(minutes) min: locked again on time, with the app closed")
            let relocked = try XCTUnwrap(phone.store.lastRelockAt)
            XCTAssertEqual(relocked.timeIntervalSince(until), 0, accuracy: 1)
            XCTAssertNil(phone.reminder, "the monitor relocked, so the safety reminder never shows")
            XCTAssertNil(phone.activity, "no timer left running")
            XCTAssertEqual(phone.health, .locked)
        }
    }

    func testUnlockingAgainAndAgainWithTheAppClosedAlwaysLocksAgain() {
        let phone = phone()
        for round in 0..<12 {
            phone.amen(minutes: [15, 30, 60][round % 3])
            XCTAssertFalse(phone.shielded, "round \(round): open")
            phone.advance(minutes: Double(90 + round * 37))   // hours later; the app was never opened again
            XCTAssertTrue(phone.shielded, "round \(round): unlocked, then locked again by itself")
            XCTAssertNil(phone.store.lockFault)
        }
    }

    func testTheEmergencyPassTheDailyKeyAndAPauseAllLockAgain() throws {
        let phone = phone()
        let pass = phone.amen(minutes: GateEngine.emergencyMinutes)   // 5 minutes becomes Screen Time's 15
        XCTAssertEqual(pass.timeIntervalSince(t0), 15 * 60, accuracy: 0.5)
        phone.advance(to: pass.addingTimeInterval(1))
        XCTAssertTrue(phone.shielded)

        let key = ShieldPlanner.end(atLeastMinimumFrom: phone.now,
                                    proposed: GateEngine.dailyKeyUntil(from: phone.now, resetHour: 4, calendar: TestCalendar.newYork))
        phone.store.dailyKeyUntil = key
        phone.appSync()
        XCTAssertFalse(phone.shielded, "Rest of today")
        phone.advance(to: key.addingTimeInterval(-60))
        XCTAssertFalse(phone.shielded)
        phone.advance(to: key.addingTimeInterval(1))
        XCTAssertTrue(phone.shielded, "locked again at the 4 a.m. reset")

        let paused = phone.pause(days: 3)
        XCTAssertFalse(phone.shielded)
        phone.advance(to: paused.addingTimeInterval(1))
        XCTAssertTrue(phone.shielded, "a pause ends by itself")
    }

    // MARK: startMonitoring throws: fail OPEN, say so, fix it

    func testARefusedTimerFailsOpenSaysSoAndLocksTheMomentTheAppOpens() {
        let phone = phone()
        phone.refusals = [.timerRefused]
        let until = phone.amen(minutes: 30)
        XCTAssertFalse(phone.shielded, "fail open: the Amen still opens the apps, never stuck locked")
        XCTAssertEqual(phone.store.lockFault, .timerRefused)
        XCTAssertEqual(phone.health, .paused(.timerRefused), "Home: Lock paused, tap to fix")
        XCTAssertEqual(phone.reminder, until, "a notification at the window's end asks to open the app")
        XCTAssertFalse(phone.store.screenTimeActive, "a leftover Shortcuts automation guards the apps meanwhile")

        // Nobody taps Fix and the app stays closed: nothing can relock by itself, and Home still says so.
        phone.advance(to: until.addingTimeInterval(10 * 60))
        XCTAssertFalse(phone.shielded)
        XCTAssertEqual(phone.health, .paused(.timerRefused))

        // The reminder opens the app: it locks at once and the pause is over.
        phone.appSync()
        XCTAssertTrue(phone.shielded)
        XCTAssertNil(phone.store.lockFault)
        XCTAssertNil(phone.reminder, "the reminder is withdrawn")
        XCTAssertTrue(phone.store.screenTimeActive)
        XCTAssertEqual(phone.health, .locked)
    }

    func testTapToFixStartsTheTimerAndTheAppsLockOnTime() {
        let phone = phone()
        phone.refusals = [.timerRefused]
        let until = phone.amen(minutes: 30)
        phone.advance(minutes: 5)
        phone.appSync()   // Fix
        XCTAssertFalse(phone.shielded, "still inside the window")
        XCTAssertNil(phone.store.lockFault)
        XCTAssertEqual(phone.health, .open(relocksAt: until))
        phone.advance(to: until.addingTimeInterval(1))
        XCTAssertTrue(phone.shielded)
    }

    func testEveryWayScreenTimeRefusesFailsOpenAndIsShown() {
        for fault in [LockFault.timerRefused, .tooManyTimers, .notAllowed] {
            let phone = phone()
            phone.refuseAll = fault
            let until = phone.amen(minutes: 15)
            XCTAssertFalse(phone.shielded, "\(fault): open")
            XCTAssertEqual(phone.health, .paused(fault))
            XCTAssertEqual(phone.reminder, until)
            XCTAssertFalse(fault.detail.isEmpty)

            phone.refuseAll = nil
            _ = phone.pause(days: 1)
            XCTAssertNil(phone.store.lockFault, "\(fault): the next timer Apple accepts clears it")
        }
    }

    // MARK: Apple's interval rules: never too short, never too long

    func testALostTimerWithMinutesLeftIsRestartedWithinApplesMinimumAndStillLocksOnTheWindowsEnd() throws {
        for left in [0.5, 1, 5, 10, 14, 14.5, 15, 16] {
            let phone = phone()
            let until = phone.amen(minutes: 30)
            phone.advance(to: until.addingTimeInterval(-left * 60))
            phone.reboot(dropsTimers: true)
            phone.appSync()   // back in the app
            XCTAssertFalse(phone.shielded, "\(left) min left: open for the rest of the window, not cut short")
            XCTAssertNil(phone.store.lockFault, "\(left) min left: Apple accepted the timer")
            XCTAssertGreaterThanOrEqual(try XCTUnwrap(phone.intervalsStarted.last), 15 * 60 - 1, "never under 15 minutes")
            phone.advance(to: until.addingTimeInterval(-1))
            XCTAssertFalse(phone.shielded)
            phone.advance(to: until.addingTimeInterval(60))
            XCTAssertTrue(phone.shielded, "\(left) min left: locked on the window's end")
            let late = try XCTUnwrap(phone.store.lastRelockAt).timeIntervalSince(until)
            XCTAssertGreaterThanOrEqual(late, 0)
            XCTAssertLessThanOrEqual(late, 59, "\(left) min left: within a minute of the end")
        }
    }

    func testAWeekLongPauseIsCoveredInLegsAppleAcceptsAndLocksWhenItEnds() {
        let phone = phone()
        let until = phone.pause(days: 7)
        XCTAssertFalse(phone.shielded)
        XCTAssertNil(phone.store.lockFault, "a week's interval would be refused (intervalTooLong); a 6-day leg isn't")
        phone.advance(to: until.addingTimeInterval(-60))
        XCTAssertFalse(phone.shielded, "paused the whole week")
        XCTAssertEqual(phone.intervalsStarted.count, 2, "the monitor started the second leg by itself")
        XCTAssertTrue(phone.intervalsStarted.allSatisfy { $0 < 7 * 86_400 && $0 >= 15 * 60 })
        phone.advance(to: until.addingTimeInterval(1))
        XCTAssertTrue(phone.shielded, "the pause ends by itself")
    }

    func testARefusedSecondLegIsShownAndTheAppStartsItAgain() {
        let phone = phone()
        let until = phone.pause(days: 7)
        phone.refusals = [.timerRefused]
        phone.advance(to: phone.now.addingTimeInterval(6 * 86_400 + 60))
        XCTAssertFalse(phone.shielded, "still paused")
        XCTAssertEqual(phone.store.lockFault, .rearmFailed)
        XCTAssertEqual(phone.reminder, until, "a notification when the pause ends")
        XCTAssertEqual(phone.health, .paused(.rearmFailed))
        phone.advance(minutes: 60)
        phone.appSync()
        XCTAssertNil(phone.store.lockFault)
        phone.advance(to: until.addingTimeInterval(1))
        XCTAssertTrue(phone.shielded)
    }

    // MARK: The 20-activity limit

    func testPrayToScrollOnlyEverUsesOneDeviceActivity() throws {
        // One DeviceActivityName in all the code, and every new timer replaces it.
        let app = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        var names = 0
        for dir in ["PrayToScroll", "Shared", "StrictLock"] {
            let files = FileManager.default.enumerator(atPath: app.appendingPathComponent(dir).path)?.allObjects as? [String] ?? []
            for file in files where file.hasSuffix(".swift") {
                let source = try String(contentsOf: app.appendingPathComponent(dir).appendingPathComponent(file), encoding: .utf8)
                names += source.components(separatedBy: "DeviceActivityName(\"").count - 1
            }
        }
        XCTAssertEqual(names, 1, "one relock activity")

        let phone = phone()
        for round in 0..<40 {
            phone.amen(minutes: 15 + round % 4 * 15)
            phone.advance(minutes: Double(round % 5) * 9)
        }
        XCTAssertEqual(phone.mostActivitiesAtOnce, 1)

        // If the phone were over Apple's limit anyway, the lock fails open and says so.
        let full = self.phone()
        full.otherActivities = 20
        full.amen(minutes: 15)
        XCTAssertFalse(full.shielded)
        XCTAssertEqual(full.health, .paused(.tooManyTimers))
    }

    // MARK: The app killed mid-unlock, a reboot, an iOS update

    func testAnAmenKilledBeforeTheShieldCameDownOpensOnTheNextLaunchAndStillRelocks() {
        let phone = phone()
        let until = phone.amenKilledBeforeUnshield(minutes: 30)
        XCTAssertTrue(phone.shielded, "killed before the shield came down")
        XCTAssertNotNil(phone.activity, "the timer was started first")
        phone.advance(minutes: 1)
        phone.appSync()   // relaunch
        XCTAssertFalse(phone.shielded, "the next launch opens what the Amen paid for")
        XCTAssertEqual(phone.intervalsStarted.count, 1, "the running timer is kept")
        phone.advance(to: until.addingTimeInterval(1))
        XCTAssertTrue(phone.shielded)
    }

    func testAnAmenKilledBeforeTheTimerStartedOpensWithATimerOnTheNextLaunch() {
        let phone = phone()
        let until = t0.addingTimeInterval(30 * 60)
        phone.store.unlockedUntil = until   // the window was written, then the app died
        phone.advance(minutes: 1)
        phone.appSync()
        XCTAssertFalse(phone.shielded)
        XCTAssertEqual(phone.health, .open(relocksAt: until))
        phone.advance(to: until.addingTimeInterval(1))
        XCTAssertTrue(phone.shielded)
    }

    func testARebootOrIOSUpdateThatDropsTheTimerIsRestartedOnTheNextOpen() {
        let phone = phone()
        let until = phone.amen(minutes: 60)
        phone.advance(minutes: 10)
        phone.reboot(dropsTimers: true)
        XCTAssertFalse(RelockEngine.isMonitoring(device: phone, store: phone.store, now: phone.now), "the timer is gone")
        phone.appSync()
        XCTAssertNotNil(phone.activity, "started again for the same end")
        XCTAssertEqual(phone.health, .open(relocksAt: until))
        phone.advance(to: until.addingTimeInterval(1))
        XCTAssertTrue(phone.shielded)

        let kept = self.phone()
        kept.amen(minutes: 60)
        kept.reboot(dropsTimers: false)
        kept.appSync()
        XCTAssertEqual(kept.intervalsStarted.count, 1, "a timer that survived the reboot is kept")
    }

    func testIfIOSNeverCallsTheMonitorTheSafetyReminderAndTheNextSyncLockTheApps() throws {
        let phone = phone()
        phone.deliversCallbacks = false
        let until = phone.amen(minutes: 30)
        phone.advance(to: until.addingTimeInterval(5 * 60))
        XCTAssertFalse(phone.shielded, "iOS didn't call the monitor")
        let reminder = try XCTUnwrap(phone.reminder, "the safety reminder is still pending, so it was shown")
        XCTAssertLessThanOrEqual(reminder, phone.now)
        XCTAssertFalse(RelockEngine.isMonitoring(device: phone, store: phone.store, now: phone.now),
                       "a finished timer iOS still lists doesn't count as running")
        phone.appSync()   // the reminder (or simply opening or leaving the app)
        XCTAssertTrue(phone.shielded)
        XCTAssertNil(phone.reminder)
    }

    // MARK: Time-zone changes

    func testAWestwardTimeZoneChangeIsCaughtByTheNextSyncAndTheAppsLockOnTime() throws {
        let phone = phone()
        let until = phone.amen(minutes: 120)
        phone.advance(minutes: 30)
        phone.zone = TimeZone(identifier: "America/Los_Angeles")!
        // The schedule is wall-clock: read in the new zone it would end 3 hours late.
        XCTAssertEqual(try XCTUnwrap(phone.activityEnd).timeIntervalSince(until), 3 * 3600 + 60, accuracy: 1)
        XCTAssertFalse(RelockEngine.isMonitoring(device: phone, store: phone.store, now: phone.now))
        phone.appSync()   // NSSystemTimeZoneDidChange while the app runs, or the next open
        XCTAssertEqual(try XCTUnwrap(phone.activityWarning).timeIntervalSince(until), 0, accuracy: 1)
        phone.advance(to: until.addingTimeInterval(1))
        XCTAssertTrue(phone.shielded, "locked at the right moment in the new time zone")
    }

    func testAnEastwardTimeZoneChangeWithTheAppClosedStillLocksOnTime() {
        let phone = phone()
        let until = phone.amen(minutes: 120)
        phone.advance(minutes: 30)
        phone.zone = TimeZone(identifier: "America/Halifax")!   // an hour east: the old schedule ends an hour early
        phone.advance(to: until.addingTimeInterval(-60))
        XCTAssertFalse(phone.shielded, "the early end found the window still open and started a new timer")
        phone.advance(to: until.addingTimeInterval(1))
        XCTAssertTrue(phone.shielded)
    }

    func testAWestwardChangeWithTheAppClosedLocksLateByAtMostTheTimeDifference() throws {
        // The known limit: iOS reads the old wall-clock end in the new zone and nothing runs until it fires. It still
        // locks by itself, and the safety reminder fires on time.
        let phone = phone()
        let until = phone.amen(minutes: 60)
        phone.zone = TimeZone(identifier: "America/Chicago")!   // an hour west
        phone.advance(to: until.addingTimeInterval(5 * 60))
        XCTAssertFalse(phone.shielded)
        XCTAssertLessThanOrEqual(try XCTUnwrap(phone.reminder), phone.now, "the safety reminder already asked to open the app")
        phone.advance(to: until.addingTimeInterval(3600 + 61))
        XCTAssertTrue(phone.shielded, "locked by itself, an hour late")
    }

    // MARK: Screen Time access turned off, an iOS update's re-auth

    func testTurningScreenTimeAccessOffNeverLeavesTheAppsLockedAndHomeSaysSo() {
        let phone = phone()
        XCTAssertTrue(phone.shielded)
        phone.authorized = false   // Settings › Screen Time › Apps with Screen Time Access, or an iOS update's reset
        phone.appSync()
        XCTAssertFalse(phone.shielded, "no access, no lock: never stuck locked")
        XCTAssertNil(phone.activity)
        XCTAssertEqual(phone.health, .accessOff, "Home: Screen Time access is off")
        XCTAssertFalse(phone.store.screenTimeActive, "a leftover Shortcuts gate takes over")

        phone.authorized = true
        phone.appSync()
        XCTAssertTrue(phone.shielded, "access back: locked again")
        XCTAssertEqual(phone.health, .locked)
    }

    func testAccessThatWasNeverGrantedIsNotReportedAsTurnedOff() {
        let phone = SimulatedPhone(now: t0)
        phone.authorized = false
        phone.appSync()
        XCTAssertEqual(phone.health, .off, "a new user sees setup, not an alarm")
    }

    func testAccessLostInTheMiddleOfAWindowFailsOpen() {
        let phone = phone()
        phone.refusals = [.notAllowed]
        phone.amen(minutes: 30)
        XCTAssertFalse(phone.shielded)
        XCTAssertEqual(phone.health, .paused(.notAllowed))
    }

    func testEveryApprovedScreenTimeStatusCountsAsApproved() {
        XCTAssertEqual(LockAuthorization(screenTimeStatus: 0), .notDetermined)
        XCTAssertEqual(LockAuthorization(screenTimeStatus: 1), .denied)
        XCTAssertEqual(LockAuthorization(screenTimeStatus: 2), .approved)
        XCTAssertEqual(LockAuthorization(screenTimeStatus: 3), .approved, "iOS 26.4's approvedWithDataAccess")
        XCTAssertEqual(LockAuthorization(screenTimeStatus: 9), .notDetermined, "unknown: ask again, never trust it")
    }

    // MARK: Two random weeks of everything going wrong

    /// Prayers, passes, pauses, the Daily key, refusals, reboots, kills, dropped callbacks, time-zone changes, access
    /// turned off and on. Whatever happens: right after any sync an open window is never shielded (never stuck
    /// locked); the apps are never open after a window without either a pending reminder or a visible fault, and the
    /// next sync always locks them.
    func testRandomWeeksNeverStuckLockedAndNeverSilentlyOpen() {
        var rng = SplitMix64(seed: 0x10C4)
        for run in 0..<30 {
            let phone = phone()
            phone.callbackJitter = { Double.random(in: 0...30, using: &rng) }
            let zones = ["America/New_York", "America/Chicago", "America/Los_Angeles", "Europe/London", "Asia/Tokyo"]
            func plan() -> ShieldPlan {
                ShieldPlanner.plan(now: phone.now, active: phone.active, unlockedUntil: phone.store.unlockedUntil,
                                   pausedUntil: phone.store.pausedUntil, dailyKeyUntil: phone.store.dailyKeyUntil)
            }
            func syncAndCheck(_ what: String) {
                phone.appSync()
                if case .open = plan() { XCTAssertFalse(phone.shielded, "run \(run): stuck locked after \(what)") }
                if plan() == .shielded { XCTAssertTrue(phone.shielded, "run \(run): open after \(what) with the window over") }
            }
            for _ in 0..<150 {
                phone.advance(to: phone.now.addingTimeInterval(Double.random(in: 20...(70 * 60), using: &rng)))
                if plan() == .shielded, !phone.shielded {
                    // Open after a window: only with the person told, by a fault on Home or a reminder due within
                    // 3 minutes of the window's end.
                    let ended = [phone.store.unlockedUntil, phone.store.pausedUntil, phone.store.dailyKeyUntil]
                        .compactMap { $0 }.filter { $0 <= phone.now }.max() ?? phone.now
                    let reminded = phone.reminder.map { $0 <= ended.addingTimeInterval(ShieldPlanner.safetyReminderDelay + 1) } ?? false
                    XCTAssertTrue(phone.store.lockFault != nil || reminded, "run \(run): silently open at \(phone.now)")
                }
                let faults: [LockFault] = [.timerRefused, .tooManyTimers, .notAllowed]
                phone.refusals = Int.random(in: 0..<8, using: &rng) == 0 ? [faults.randomElement(using: &rng)!] : []
                switch Int.random(in: 0..<14, using: &rng) {
                case 0, 1, 2:
                    phone.amen(minutes: [15, 30, 60, 180].randomElement(using: &rng)!)
                    if case .open = plan() { XCTAssertFalse(phone.shielded, "run \(run): an Amen left the apps locked") }
                case 3:
                    phone.store.dailyKeyUntil = ShieldPlanner.end(atLeastMinimumFrom: phone.now, proposed: GateEngine.dailyKeyUntil(
                        from: phone.now, resetHour: 4, calendar: phone.calendar))
                    syncAndCheck("the Daily key")
                case 4:
                    phone.store.pausedUntil = phone.store.pausedUntil == nil ? phone.calendar.date(byAdding: .day, value: 7, to: phone.now) : nil
                    syncAndCheck("a pause")
                case 5:
                    phone.reboot(dropsTimers: Bool.random(using: &rng))
                case 6:
                    phone.zone = TimeZone(identifier: zones.randomElement(using: &rng)!)!
                    syncAndCheck("a time-zone change")   // the app hears NSSystemTimeZoneDidChange, or opens next
                case 7:
                    phone.authorized.toggle()
                    syncAndCheck("access \(phone.authorized ? "back" : "off")")
                case 8:
                    phone.deliversCallbacks.toggle()
                default:
                    phone.refusals = []
                    syncAndCheck("opening the app")
                }
            }
        }
    }
}
#endif
