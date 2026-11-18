// STRICT_LOCK-ONLY: the Screen Time lock's simulated iPhone (project-strictlock.yml); STRICT_LOCK=1 tools/run-unit-tests.sh runs it.
#if STRICT_LOCK
import Foundation
@testable import PrayToScroll

/// An iPhone as far as Strict Lock touches it, with Apple's rules: a DeviceActivity interval must be 15 minutes or
/// longer and shorter than a week (intervalTooShort / intervalTooLong), at most 20 activities (excessiveActivities),
/// a schedule is wall-clock DateComponents read in the phone's CURRENT time zone, and the monitor extension gets
/// intervalWillEndWarning at `end − warningTime` and intervalDidEnd at `end`, even while the app isn't running.
///
/// The app side runs the real RelockEngine.sync (what AppModel.syncLock runs), and the monitor the real
/// RelockEngine.monitorFired (what DeviceActivityMonitorExtension runs), against this phone and a scratch app group.
final class SimulatedPhone: ScreenTimeDevice {
    struct Activity {
        let start: DateComponents
        let end: DateComponents
        let warning: DateComponents?
        var warned = false
        /// Over, but iOS still lists it (its callback never came).
        var finished = false
    }

    let store = SharedStore(defaults: makeScratchDefaults())
    var now: Date
    var zone: TimeZone
    /// Screen Time access (FamilyControls .individual).
    var authorized = true
    var picked = 3
    var shielded = false
    /// The next startMonitoring calls throw these, in order.
    var refusals: [LockFault] = []
    /// Every startMonitoring call throws this.
    var refuseAll: LockFault?
    /// Other DeviceActivity schedules of this app (Pray to Scroll has none; the limit is 20).
    var otherActivities = 0
    /// The monitor's callbacks arrive up to this early (Apple's are a little early sometimes).
    var callbackJitter: () -> TimeInterval = { 0 }
    /// False: iOS never calls the monitor (the worst case), and a finished schedule stays listed.
    var deliversCallbacks = true
    private(set) var activity: Activity?
    private(set) var reminder: Date?
    private(set) var intervalsStarted: [TimeInterval] = []
    private(set) var mostActivitiesAtOnce = 0

    init(now: Date, zone: String = "America/New_York") {
        self.now = now
        self.zone = TimeZone(identifier: zone)!
        var settings = AppSettings()
        settings.gateEnabled = true
        settings.lockMethod = .screenTime
        store.settings = settings
    }

    // MARK: ScreenTimeDevice (Apple's side)

    var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        return calendar
    }

    var isShielded: Bool { shielded }
    func shield() { if authorized { shielded = true } }   // without access ManagedSettings changes nothing
    func unshield() { shielded = false }

    func startRelockActivity(start: DateComponents, end: DateComponents, warning: DateComponents?) throws {
        if let refuseAll { throw refuseAll }
        if !refusals.isEmpty { throw refusals.removeFirst() }
        guard authorized else { throw LockFault.notAllowed }
        guard activity != nil || otherActivities < 20 else { throw LockFault.tooManyTimers }
        let from = calendar.date(from: start)!, to = calendar.date(from: end)!
        let length = to.timeIntervalSince(from)
        guard length >= 15 * 60 - 1 else { throw LockFault.timerRefused }   // intervalTooShort
        guard length < 7 * 86_400 else { throw LockFault.timerRefused }     // intervalTooLong
        activity = Activity(start: start, end: end, warning: warning)
        intervalsStarted.append(length)
        mostActivitiesAtOnce = max(mostActivitiesAtOnce, otherActivities + 1)
    }

    func stopRelockActivity() { activity = nil }
    var relockActivityEnd: DateComponents? { activity?.end }
    func remindToRelock(at date: Date?) { reminder = date }

    /// When the running activity's warning and end fire, as iOS reads its components now (in the current zone).
    var activityEnd: Date? {
        guard let activity, !activity.finished else { return nil }
        return calendar.date(from: activity.end)
    }
    var activityWarning: Date? {
        guard let activity, !activity.warned, let minutes = activity.warning?.minute, let end = activityEnd else { return nil }
        return end.addingTimeInterval(-Double(minutes) * 60)
    }

    // MARK: The app (AppModel.syncLock's code)

    var active: Bool { store.settings.gateEnabled && store.settings.lockMethod == .screenTime && authorized && picked > 0 }

    /// The app syncs: an Amen, a pause, opening or leaving it, a time-zone change, access changing.
    @discardableResult
    func appSync() -> ShieldPlan {
        if authorized { store.screenTimeWasApproved = true }
        return RelockEngine.sync(now: now, active: active, store: store, scheduledRelock: store.relockScheduledFor,
                                 monitoring: RelockEngine.isMonitoring(device: self, store: store, now: now),
                                 shield: shield, unshield: unshield, isShielded: { self.shielded },
                                 schedule: { try RelockEngine.schedule(at: $0, now: self.now, device: self, store: self.store) },
                                 cancel: { RelockEngine.cancel(device: self, store: self.store) },
                                 remind: remindToRelock)
    }

    /// An Amen: the window AppModel.applyUnlock writes (never under 15 minutes under Screen Time), then a sync.
    @discardableResult
    func amen(minutes: Int) -> Date {
        let until = ShieldPlanner.end(atLeastMinimumFrom: now,
                                      proposed: GateEngine.unlock(from: now, minutes: minutes, existing: store.unlockedUntil))
        store.unlockedUntil = until
        appSync()
        return until
    }

    func pause(days: Int) -> Date {
        let until = calendar.date(byAdding: .day, value: days, to: now)!
        store.pausedUntil = until
        appSync()
        return until
    }

    var health: LockHealth {
        let plan = ShieldPlanner.plan(now: now, active: active, unlockedUntil: store.unlockedUntil,
                                      pausedUntil: store.pausedUntil, dailyKeyUntil: store.dailyKeyUntil)
        let accessLost = store.settings.gateEnabled && store.settings.lockMethod == .screenTime && !authorized
            && store.screenTimeWasApproved
        let verified = RelockEngine.isMonitoring(device: self, store: store, now: now) ? store.relockScheduledFor : nil
        return ShieldPlanner.health(plan: plan, accessLost: accessLost, fault: store.lockFault, verifiedRelock: verified)
    }

    // MARK: iOS

    /// Time passes with the app closed: the monitor gets its warning and end callbacks when they're due.
    func advance(to time: Date) {
        while let fire = [activityWarning, activityEnd].compactMap({ $0 }).min(), fire <= time {
            let ended = activityWarning == nil
            if !deliversCallbacks {
                if ended { activity?.finished = true } else { activity?.warned = true }
                continue
            }
            now = max(now, fire.addingTimeInterval(-max(0, callbackJitter())))
            if ended { activity = nil } else { activity?.warned = true }
            RelockEngine.monitorFired(intervalEnded: ended, now: now, device: self, store: store, hasSelection: picked > 0)
            now = max(now, fire)
        }
        now = max(now, time)
    }

    func advance(minutes: Double) { advance(to: now.addingTimeInterval(minutes * 60)) }

    /// A restart: shields stay; `dropsTimers` models a schedule lost on the way (a reboot or an iOS update).
    func reboot(dropsTimers: Bool) {
        if dropsTimers { activity = nil }
    }

    /// The app is killed between starting the timer and lifting the shield (an Amen cut short).
    func amenKilledBeforeUnshield(minutes: Int) -> Date {
        let until = ShieldPlanner.end(atLeastMinimumFrom: now, proposed: now.addingTimeInterval(Double(minutes) * 60))
        store.unlockedUntil = until
        try? RelockEngine.schedule(at: until, now: now, device: self, store: store)
        return until
    }
}
#endif
