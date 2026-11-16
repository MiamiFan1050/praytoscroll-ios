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

    func testNeverStartsATimerShorterThanFifteenMinutes() {
        // The timer for this window was lost (monitoring false) and only 5 minutes are left: lock now, never open blind.
        XCTAssertEqual(ShieldPlanner.step(for: .open(until: min(5)), now: now, scheduledRelock: min(5), monitoring: false), .shield)
        XCTAssertEqual(ShieldPlanner.step(for: .open(until: min(14)), now: now, scheduledRelock: nil, monitoring: false), .shield)
        XCTAssertEqual(ShieldPlanner.step(for: .open(until: min(15)), now: now, scheduledRelock: nil, monitoring: false),
                       .scheduleThenOpen(until: min(15)))
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

    func testAFailedTimerKeepsTheAppsShielded() {
        struct Refused: Error {}
        var shielded = true
        let ok = ShieldPlanner.perform(.scheduleThenOpen(until: min(15)), now: now, shield: { shielded = true },
                                       unshield: { shielded = false }, schedule: { _ in throw Refused() }, cancel: {})
        XCTAssertFalse(ok)
        XCTAssertTrue(shielded, "no timer, no opening: a relock must never fail silently")
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
    /// running relock timer, and once a window is over they are shielded.
    func testRandomWeeksNeverLeaveTheAppsOpenWithoutATimer() {
        var rng = SplitMix64(seed: 0x5EED)
        for _ in 0..<40 {
            var device = SimulatedDevice()
            var t = now
            var unlocked: Date?
            var paused: Date?
            var daily: Date?
            func sync() {
                let plan = ShieldPlanner.plan(now: t, active: true, unlockedUntil: unlocked, pausedUntil: paused, dailyKeyUntil: daily)
                let step = ShieldPlanner.step(for: plan, now: t, scheduledRelock: device.timerEnd, monitoring: device.timerEnd.map { $0 > t } ?? false)
                ShieldPlanner.perform(step, now: t, shield: { device.shielded = true }, unshield: { device.shielded = false },
                                      schedule: { end in
                                          if Int.random(in: 0..<10, using: &rng) == 0 { throw SimulatedDevice.Refused() }
                                          device.timerEnd = end
                                      }, cancel: { device.timerEnd = nil })
            }
            func monitorFiresIfDue(before next: Date) {
                // DeviceActivity calls intervalDidEnd at the timer's end (sometimes up to 30 s early).
                while let end = device.timerEnd, end <= next {
                    t = max(t, end.addingTimeInterval(-Double.random(in: 0...30, using: &rng)))
                    device.timerEnd = nil
                    let plan = ShieldPlanner.plan(now: t, active: true, unlockedUntil: unlocked, pausedUntil: paused,
                                                  dailyKeyUntil: daily, slack: ShieldPlanner.monitorSlack)
                    if case .open = plan {} else { device.shielded = true }
                    t = max(t, end)
                    check()
                }
            }
            func check() {
                if !device.shielded {
                    XCTAssertNotNil(device.timerEnd, "open with no relock timer at \(t)")
                    if let end = device.timerEnd { XCTAssertGreaterThanOrEqual(end, t) }
                }
                let plan = ShieldPlanner.plan(now: t, active: true, unlockedUntil: unlocked, pausedUntil: paused,
                                              dailyKeyUntil: daily, slack: ShieldPlanner.monitorSlack)
                if plan == .shielded, device.timerEnd == nil { XCTAssertTrue(device.shielded, "window over but still open at \(t)") }
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
