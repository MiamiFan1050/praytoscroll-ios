// STRICT_LOCK-ONLY: the Screen Time lock's planner (project-strictlock.yml); STRICT_LOCK=1 tools/run-unit-tests.sh runs it.
#if STRICT_LOCK
import XCTest
@testable import PrayToScroll

/// Strict Lock's decisions (pure: runs in the local Catalyst runner too).
final class ShieldPlannerTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private func min(_ m: Double) -> Date { now.addingTimeInterval(m * 60) }

    func testOffWhenStrictLockIsntInUse() {
        XCTAssertEqual(ShieldPlanner.plan(now: now, active: false, unlockedUntil: min(10), pausedUntil: nil, dailyKeyUntil: nil), .off)
        XCTAssertEqual(ShieldPlanner.step(for: .off, now: now, scheduledRelock: min(10), monitoring: true), .clear)
    }

    func testShieldedWhenNothingIsOpen() {
        XCTAssertEqual(ShieldPlanner.plan(now: now, active: true, unlockedUntil: nil, pausedUntil: nil, dailyKeyUntil: nil), .shielded)
        XCTAssertEqual(ShieldPlanner.plan(now: now, active: true, unlockedUntil: min(-1), pausedUntil: min(-60), dailyKeyUntil: min(-600)),
                       .shielded, "windows that already ended don't count")
    }

    func testOpenUntilTheLatestWindow() {
        XCTAssertEqual(ShieldPlanner.plan(now: now, active: true, unlockedUntil: min(15), pausedUntil: nil, dailyKeyUntil: nil), .open(until: min(15)))
        XCTAssertEqual(ShieldPlanner.plan(now: now, active: true, unlockedUntil: min(15), pausedUntil: min(3 * 1440), dailyKeyUntil: min(300)),
                       .open(until: min(3 * 1440)), "a pause outlasts the window and the Daily key")
        XCTAssertEqual(ShieldPlanner.plan(now: now, active: true, unlockedUntil: min(15), pausedUntil: nil, dailyKeyUntil: min(300)),
                       .open(until: min(300)))
    }

    func testANewWindowStartsItsRelockTimerBeforeOpening() {
        XCTAssertEqual(ShieldPlanner.step(for: .open(until: min(15)), now: now, scheduledRelock: nil, monitoring: false),
                       .scheduleThenOpen(until: min(15)))
        XCTAssertEqual(ShieldPlanner.step(for: .open(until: min(30)), now: now, scheduledRelock: min(15), monitoring: true),
                       .scheduleThenOpen(until: min(30)), "praying again inside a window moves the timer")
    }

    func testARunningTimerForTheSameEndIsKept() {
        XCTAssertEqual(ShieldPlanner.step(for: .open(until: min(5)), now: now, scheduledRelock: min(5), monitoring: true),
                       .keepOpen(until: min(5)), "coming back to the app 10 minutes in doesn't restart anything")
    }

    func testALostTimerIsRestartedHoweverLittleTimeIsLeft() {
        // The timer for this window was lost (a reboot, an iOS update) with 5 minutes left: keep the window, start
        // another timer (RelockTimer keeps it within Apple's 15-minute minimum and still relocks on time).
        XCTAssertEqual(ShieldPlanner.step(for: .open(until: min(5)), now: now, scheduledRelock: min(5), monitoring: false),
                       .scheduleThenOpen(until: min(5)))
        XCTAssertEqual(ShieldPlanner.step(for: .open(until: min(14)), now: now, scheduledRelock: nil, monitoring: false),
                       .scheduleThenOpen(until: min(14)))
        XCTAssertEqual(ShieldPlanner.step(for: .open(until: min(15)), now: now, scheduledRelock: nil, monitoring: false),
                       .scheduleThenOpen(until: min(15)))
    }

    func testEveryRelockGetsAWarningOnTheWindowsEndAndABackupEndAMinuteLater() {
        let normal = ShieldPlanner.timer(relockAt: min(30), now: now)
        XCTAssertEqual(normal.start, now)
        XCTAssertEqual(normal.end, min(31), "the backup: the interval ends a minute after the window")
        XCTAssertEqual(normal.warningMinutes, 1)
        XCTAssertEqual(normal.warningAt, min(30), "the warning lands on the window's end")
        XCTAssertEqual(normal.firesAt, min(30))
    }

    func testAShortWindowStillGetsApplesFifteenMinutesAndRelocksOnItsEnd() {
        for left in [0.5, 1, 5, 14, 14.5] {
            let timer = ShieldPlanner.timer(relockAt: min(left), now: now)
            XCTAssertGreaterThanOrEqual(timer.length, 15 * 60, "\(left) min: never intervalTooShort")
            let lands = (timer.warningAt ?? timer.end).timeIntervalSince(min(left))
            XCTAssertGreaterThanOrEqual(lands, 0, "\(left) min: never before the window's end")
            XCTAssertLessThanOrEqual(lands, 59, "\(left) min: within a minute of it")
        }
    }

    func testAWeekLongWindowIsCoveredInLegsShorterThanAWeek() {
        let timer = ShieldPlanner.timer(relockAt: min(7 * 1440), now: now)
        XCTAssertEqual(timer.end, min(6 * 1440), "a week would be intervalTooLong")
        XCTAssertNil(timer.warningMinutes, "a leg ends before the window: its end starts the next leg")
        XCTAssertEqual(ShieldPlanner.monitorAction(now: min(6 * 1440), active: true, unlockedUntil: nil, pausedUntil: min(7 * 1440),
                                                   dailyKeyUntil: nil, intervalEnded: true), .rearm(until: min(7 * 1440)))
        let last = ShieldPlanner.timer(relockAt: min(7 * 1440), now: min(6 * 1440))
        XCTAssertEqual(last.warningAt, min(7 * 1440))
    }

    func testTheScheduleIsWallClockSoATimeZoneChangeMakesTheTimerStale() {
        var newYork = Calendar(identifier: .gregorian)
        newYork.timeZone = TimeZone(identifier: "America/New_York")!
        var chicago = newYork
        chicago.timeZone = TimeZone(identifier: "America/Chicago")!
        let timer = ShieldPlanner.timer(relockAt: min(60), now: now)
        let parts = ShieldPlanner.scheduleParts(for: timer, calendar: newYork)
        XCTAssertEqual(parts.warning, DateComponents(minute: 1))
        XCTAssertEqual(newYork.date(from: parts.end), timer.end)
        XCTAssertTrue(ShieldPlanner.timerIsCurrent(scheduledEnd: parts.end, expectedEnd: timer.end, scheduledZone: "America/New_York",
                                                   calendar: newYork, now: now))
        XCTAssertFalse(ShieldPlanner.timerIsCurrent(scheduledEnd: parts.end, expectedEnd: timer.end, scheduledZone: "America/New_York",
                                                    calendar: chicago, now: now), "an hour west: it would end an hour late")
        // If iOS hands the end back tagged with its old zone, the instant still matches: the zone check catches it.
        var tagged = parts.end
        tagged.timeZone = newYork.timeZone
        XCTAssertFalse(ShieldPlanner.timerIsCurrent(scheduledEnd: tagged, expectedEnd: timer.end, scheduledZone: "America/New_York",
                                                    calendar: chicago, now: now), "set in another time zone")
        XCTAssertFalse(ShieldPlanner.timerIsCurrent(scheduledEnd: parts.end, expectedEnd: timer.end, scheduledZone: "America/New_York",
                                                    calendar: newYork, now: min(62)), "a finished timer isn't running")
        XCTAssertFalse(ShieldPlanner.timerIsCurrent(scheduledEnd: nil, expectedEnd: timer.end, scheduledZone: "America/New_York",
                                                    calendar: newYork, now: now), "no schedule, no timer")
    }

    func testTheMonitorShieldsAtTheWarningOrTheEndAndReArmsAWindowThatOutlastsIt() {
        XCTAssertEqual(ShieldPlanner.monitorAction(now: min(30), active: true, unlockedUntil: min(30), pausedUntil: nil,
                                                   dailyKeyUntil: nil, intervalEnded: false), .shield)
        XCTAssertEqual(ShieldPlanner.monitorAction(now: min(31), active: true, unlockedUntil: min(30), pausedUntil: nil,
                                                   dailyKeyUntil: nil, intervalEnded: true), .shield, "the backup end")
        XCTAssertEqual(ShieldPlanner.monitorAction(now: min(20), active: true, unlockedUntil: min(30), pausedUntil: nil,
                                                   dailyKeyUntil: nil, intervalEnded: false), .nothing, "a warning inside the window")
        XCTAssertEqual(ShieldPlanner.monitorAction(now: min(31), active: true, unlockedUntil: min(60), pausedUntil: nil,
                                                   dailyKeyUntil: nil, intervalEnded: true), .rearm(until: min(60)),
                       "a window that grew while its old timer ran out gets a new one")
        XCTAssertEqual(ShieldPlanner.monitorAction(now: min(31), active: false, unlockedUntil: min(30), pausedUntil: nil,
                                                   dailyKeyUntil: nil, intervalEnded: true), .nothing, "gate off: nothing to lock")
    }

    func testTheLockCheckOnHome() {
        XCTAssertEqual(ShieldPlanner.health(plan: .shielded, accessLost: false, fault: nil, verifiedRelock: nil), .locked)
        XCTAssertEqual(ShieldPlanner.health(plan: .open(until: min(30)), accessLost: false, fault: nil, verifiedRelock: min(30)),
                       .open(relocksAt: min(30)))
        XCTAssertEqual(ShieldPlanner.health(plan: .open(until: min(30)), accessLost: false, fault: nil, verifiedRelock: nil),
                       .paused(.timerRefused), "open with no confirmed timer is never shown as fine")
        XCTAssertEqual(ShieldPlanner.health(plan: .open(until: min(30)), accessLost: false, fault: nil, verifiedRelock: min(15)),
                       .paused(.timerRefused), "a timer for another end doesn't count")
        XCTAssertEqual(ShieldPlanner.health(plan: .open(until: min(30)), accessLost: false, fault: .notAllowed, verifiedRelock: min(30)),
                       .paused(.notAllowed))
        XCTAssertEqual(ShieldPlanner.health(plan: .shielded, accessLost: false, fault: .timerRefused, verifiedRelock: nil),
                       .paused(.timerRefused), "a paused lock whose window ended is open until the next sync")
        XCTAssertEqual(ShieldPlanner.health(plan: .off, accessLost: true, fault: nil, verifiedRelock: nil), .accessOff)
        XCTAssertEqual(ShieldPlanner.health(plan: .off, accessLost: false, fault: .timerRefused, verifiedRelock: nil), .off)
    }

    func testTheMonitorTreatsAWindowEndingWithinItsSlackAsOver() {
        let plan = ShieldPlanner.plan(now: now, active: true, unlockedUntil: now.addingTimeInterval(30), pausedUntil: nil,
                                      dailyKeyUntil: nil, slack: ShieldPlanner.monitorSlack)
        XCTAssertEqual(plan, .shielded, "intervalDidEnd arriving 30 s early still relocks")
    }

    func testFifteenMinuteMinimumUnderScreenTime() {
        XCTAssertEqual(ShieldPlanner.end(atLeastMinimumFrom: now, proposed: min(5)), min(15))
        XCTAssertEqual(ShieldPlanner.end(atLeastMinimumFrom: now, proposed: min(60)), min(60))
        XCTAssertEqual(ShieldPlanner.windowOptions(for: .screenTime), [15, 30, 45, 60, 120, 180])
        XCTAssertEqual(ShieldPlanner.windowOptions(for: .shortcuts), [5, 15, 30, 45, 60, 120, 180])
        XCTAssertEqual(ShieldPlanner.minimumWindowMinutes(for: .screenTime), 15)
        XCTAssertEqual(ShieldPlanner.minimumWindowMinutes(for: .shortcuts), 5)
        XCTAssertEqual(ShieldPlanner.effectiveWindowMinutes(5, method: .screenTime), 15)
        XCTAssertEqual(ShieldPlanner.effectiveWindowMinutes(5, method: .shortcuts), 5)
        XCTAssertEqual(ShieldPlanner.emergencyMinutes(for: .screenTime), 15)
        XCTAssertEqual(ShieldPlanner.emergencyMinutes(for: .shortcuts), 5)
    }

    func testAFailedTimerFailsOpenAndSaysWhy() {
        struct Refused: Error {}
        var shielded = true
        let outcome = ShieldPlanner.perform(.scheduleThenOpen(until: min(15)), now: now, shield: { shielded = true },
                                            unshield: { shielded = false }, schedule: { _ in throw Refused() }, cancel: {})
        XCTAssertEqual(outcome, .failedOpen(.timerRefused, until: min(15)), "reported, never silent")
        XCTAssertFalse(shielded, "fail open: a prayer never leaves anyone locked out")
        let typed = ShieldPlanner.perform(.scheduleThenOpen(until: min(15)), now: now, shield: {}, unshield: {},
                                          schedule: { _ in throw LockFault.tooManyTimers }, cancel: {})
        XCTAssertEqual(typed, .failedOpen(.tooManyTimers, until: min(15)))
        var order: [String] = []
        let done = ShieldPlanner.perform(.scheduleThenOpen(until: min(15)), now: now, shield: { order.append("shield") },
                                         unshield: { order.append("unshield") }, schedule: { _ in order.append("schedule") },
                                         cancel: { order.append("cancel") })
        XCTAssertEqual(done, .done)
        XCTAssertEqual(order, ["schedule", "unshield"], "the timer starts BEFORE the shield comes down")
    }

    func testScreenTimeTakesOverFromALeftoverShortcutsAutomation() {
        var snapshot = GateSnapshot(gateEnabled: true, gatedAppIDs: ["instagram"], customApps: [], unlockedUntil: nil,
                                    pausedUntil: nil, dailyKeyUntil: nil)
        XCTAssertEqual(GateEngine.decide(appID: "instagram", now: now, snapshot: snapshot), .requirePrayer)
        snapshot.screenTimeActive = true
        XCTAssertEqual(GateEngine.decide(appID: "instagram", now: now, snapshot: snapshot), .allow(until: nil, reason: .screenTime),
                       "the shield already asked for the prayer; the automation doesn't ask twice")
    }

    /// A simulated iPhone over two random weeks: prayers, emergency passes, pauses, the Daily key, the app coming
    /// and going, Screen Time sometimes refusing a timer. Whatever happens, the apps are never open without a
    /// running relock timer unless the lock reports itself paused, an open window is never shielded after a sync,
    /// and once a window is over they are shielded. (LockFailureTests runs the full engine on a simulated iPhone.)
    func testRandomWeeksNeverLeaveTheAppsOpenWithoutATimerOrAWarning() {
        var rng = SplitMix64(seed: 0x5EED)
        for _ in 0..<40 {
            var device = SimulatedDevice()
            var t = now
            var unlocked: Date?
            var paused: Date?
            var daily: Date?
            var paused_ = false   // the lock reported itself paused (failed open)
            func sync() {
                let plan = ShieldPlanner.plan(now: t, active: true, unlockedUntil: unlocked, pausedUntil: paused, dailyKeyUntil: daily)
                let step = ShieldPlanner.step(for: plan, now: t, scheduledRelock: device.timerEnd, monitoring: device.timerEnd.map { $0 > t } ?? false)
                let outcome = ShieldPlanner.perform(step, now: t, shield: { device.shielded = true }, unshield: { device.shielded = false },
                                                    schedule: { end in
                                                        if Int.random(in: 0..<10, using: &rng) == 0 { throw SimulatedDevice.Refused() }
                                                        device.timerEnd = end
                                                    }, cancel: { device.timerEnd = nil })
                paused_ = outcome != .done
                if case .open = plan { XCTAssertFalse(device.shielded, "stuck locked at \(t)") }
            }
            func monitorFiresIfDue(before next: Date) {
                // DeviceActivity calls intervalDidEnd at the timer's end (sometimes up to 30 s early).
                while let end = device.timerEnd, end <= next {
                    t = max(t, end.addingTimeInterval(-Double.random(in: 0...30, using: &rng)))
                    device.timerEnd = nil
                    switch ShieldPlanner.monitorAction(now: t, active: true, unlockedUntil: unlocked, pausedUntil: paused,
                                                       dailyKeyUntil: daily, intervalEnded: true) {
                    case .shield: device.shielded = true
                    case .rearm(let until): device.timerEnd = until
                    case .nothing: break
                    }
                    t = max(t, end)
                    check()
                }
            }
            func check() {
                if !device.shielded {
                    XCTAssertTrue(device.timerEnd != nil || paused_, "open with no relock timer and nothing said at \(t)")
                    if let end = device.timerEnd { XCTAssertGreaterThanOrEqual(end, t) }
                }
                let plan = ShieldPlanner.plan(now: t, active: true, unlockedUntil: unlocked, pausedUntil: paused,
                                              dailyKeyUntil: daily, slack: ShieldPlanner.monitorSlack)
                if plan == .shielded, device.timerEnd == nil, !paused_ { XCTAssertTrue(device.shielded, "window over but still open at \(t)") }
            }
            sync()
            for _ in 0..<120 {
                let next = t.addingTimeInterval(Double.random(in: 30...(50 * 60), using: &rng))
                monitorFiresIfDue(before: next)
                t = next
                switch Int.random(in: 0..<10, using: &rng) {
                case 0, 1, 2:   // a prayer opens a 15/30/60-minute window (stacking, never shorter than 15)
                    let minutes = [15, 30, 60].randomElement(using: &rng)!
                    unlocked = ShieldPlanner.end(atLeastMinimumFrom: t,
                                                 proposed: GateEngine.unlock(from: t, minutes: minutes, existing: unlocked))
                case 3:         // the emergency pass
                    unlocked = ShieldPlanner.end(atLeastMinimumFrom: t, proposed: GateEngine.unlock(from: t, minutes: 15, existing: unlocked))
                case 4:         // the Daily key, at least 15 minutes even just before the reset
                    daily = ShieldPlanner.end(atLeastMinimumFrom: t,
                                              proposed: GateEngine.dailyKeyUntil(from: t, resetHour: 4, calendar: Calendar(identifier: .gregorian)))
                case 5:         // pause for 1 day, or resume
                    paused = paused == nil ? t.addingTimeInterval(86_400) : nil
                default:        // the app comes back to the foreground
                    break
                }
                sync()
                check()
            }
        }
    }
}

private struct SimulatedDevice {
    struct Refused: Error {}
    var shielded = false
    var timerEnd: Date?
}
#endif
