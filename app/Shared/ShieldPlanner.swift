#if STRICT_LOCK   // the Screen Time lock: only in the project-strictlock.yml build
import Foundation

/// What Screen Time should be doing right now.
enum ShieldPlan: Equatable, Sendable {
    /// Strict Lock isn't in use (gate off, Shortcuts method, no access or no apps picked): no shield, no timer.
    case off
    /// The picked apps wait for a prayer.
    case shielded
    /// Open until `until` (a prayer window, the emergency pass, a pause or the Daily key), then shielded again.
    case open(until: Date)
}

/// What the app does to get there.
enum LockStep: Equatable, Sendable {
    /// Lift the shield and cancel any relock timer.
    case clear
    /// Put the shield up (and cancel a stale relock timer).
    case shield
    /// Already open with a relock timer for this exact end: just make sure the shield is down.
    case keepOpen(until: Date)
    /// Start the relock timer FIRST, then lift the shield (also when the timer is refused: the lock fails open).
    case scheduleThenOpen(until: Date)
}

/// Why Strict Lock is paused: the apps are open but nothing would lock them again by itself. The lock fails OPEN
/// (a prayer never leaves anyone locked out), and never silently: Home says "Lock paused, tap to fix", a notification
/// at the window's end asks to open the app, and every sync (opening or leaving the app, a time or time-zone change,
/// Screen Time access coming back) tries again and locks at once if the window is over.
enum LockFault: String, Codable, Equatable, Sendable, Error {
    /// DeviceActivity refused the relock timer (its interval rules or an invalid date).
    case timerRefused
    /// Too many DeviceActivity schedules (Apple's limit is 20; Pray to Scroll only ever runs one).
    case tooManyTimers
    /// Screen Time says the app isn't allowed to schedule: access was turned off or is being re-checked.
    case notAllowed
    /// A long window's (a pause's) timer ended and the monitor couldn't start the next one.
    case rearmFailed
    /// The shield didn't go back up.
    case shieldOff

    var detail: String {
        switch self {
        case .timerRefused, .rearmFailed:
            return "Screen Time didn't start the timer that locks your apps again, so they're open for now."
        case .tooManyTimers:
            return "Screen Time has too many timers running, so it couldn't set the one that locks your apps again."
        case .notAllowed:
            return "Screen Time wouldn't let Pray to Scroll set its timer. Your apps are open for now."
        case .shieldOff:
            return "Screen Time didn't put the lock back on your apps."
        }
    }
}

/// The DeviceActivity interval behind one relock. Every relock gets two chances: the interval's end WARNING lands on
/// the window's end, and the interval itself ends a minute later as the backup. Apple only runs intervals of 15
/// minutes up to (not including) a week, so a window with less than 15 minutes left gets a 15-minute interval (the
/// warning still lands on the window's end), and a window longer than 6 days (a week's pause) is covered in legs the
/// monitor re-arms.
struct RelockTimer: Equatable, Sendable {
    /// When the apps must lock again.
    let relockAt: Date
    let start: Date
    let end: Date
    /// intervalWillEndWarning fires this many minutes before `end`: on the window's end, when that comes first.
    let warningMinutes: Int?

    var length: TimeInterval { end.timeIntervalSince(start) }
    var warningAt: Date? { warningMinutes.map { end.addingTimeInterval(-Double($0) * 60) } }
    /// The moment the monitor puts the shield back (the warning, else the interval's end).
    var firesAt: Date { warningAt ?? end }
}

/// What the DeviceActivity monitor extension does when the relock timer's warning or end arrives.
enum MonitorAction: Equatable, Sendable {
    case nothing
    case shield
    /// The window outlasts this timer (the next leg of a long pause, or a window that grew): start another.
    case rearm(until: Date)
}

/// The lock as Home shows it ("lock health"), checked after every sync.
enum LockHealth: Equatable, Sendable {
    /// Strict Lock isn't in use.
    case off
    /// Screen Time access was turned off (or reset by an iOS update): nothing is locked until it's back.
    case accessOff
    /// The picked apps are shielded.
    case locked
    /// Open, with a running relock timer for this end.
    case open(relocksAt: Date)
    /// Failed open: see LockFault.
    case paused(LockFault)
}

/// Pure Strict Lock logic, shared by the app, the DeviceActivity monitor extension and the unit tests.
enum ShieldPlanner {
    static let minimumMinutes = 15
    static var minimumInterval: TimeInterval { TimeInterval(minimumMinutes * 60) }
    /// Apple refuses (intervalTooLong) an interval of a week; legs stay well clear of it.
    static let maximumInterval: TimeInterval = 6 * 86_400
    /// The interval's end comes this long after the window's end: the backup if the warning doesn't arrive.
    static let backupDelay: TimeInterval = 60
    /// If neither callback has relocked by this long after the window's end, a notification asks to open the app
    /// (the monitor withdraws it when it relocks, so it only ever shows when iOS didn't call the monitor).
    static let safetyReminderDelay: TimeInterval = 180
    /// The monitor's callbacks can arrive a little early; a window that ends within this is treated as over.
    static let monitorSlack: TimeInterval = 60
    /// Wall-clock components DeviceActivity schedules are written in (read in the device's time zone).
    static let scheduleComponents: Set<Calendar.Component> = [.era, .year, .month, .day, .hour, .minute, .second]

    static func plan(now: Date, active: Bool, unlockedUntil: Date?, pausedUntil: Date?, dailyKeyUntil: Date?,
                     slack: TimeInterval = 0) -> ShieldPlan {
        guard active else { return .off }
        let openUntil = [unlockedUntil, pausedUntil, dailyKeyUntil]
            .compactMap { $0 }
            .filter { $0 > now.addingTimeInterval(slack) }
            .max()
        if let openUntil { return .open(until: openUntil) }
        return .shielded
    }

    /// `scheduledRelock` is the end the running relock timer was started for; `monitoring` says that timer is still
    /// running and still ends when it should (false after a reboot or iOS update dropped it, or a time-zone change
    /// moved its wall-clock end).
    static func step(for plan: ShieldPlan, now: Date, scheduledRelock: Date?, monitoring: Bool) -> LockStep {
        switch plan {
        case .off:
            return .clear
        case .shielded:
            return .shield
        case .open(let until):
            if monitoring, let scheduledRelock, abs(scheduledRelock.timeIntervalSince(until)) < 1 {
                return .keepOpen(until: until)
            }
            // A new end, or a lost timer: start one. However little is left, RelockTimer keeps Apple's interval at
            // 15 minutes and still relocks on the window's end, so a prayer is never cut short.
            return .scheduleThenOpen(until: until)
        }
    }

    enum Outcome: Equatable, Sendable {
        case done
        /// The relock timer was refused: the apps are open until `until` with nothing to lock them again.
        case failedOpen(LockFault, until: Date)
    }

    /// Carries out one step. (AppModel runs it against Apple's shields; the tests against a simulated iPhone.)
    @discardableResult
    static func perform(_ step: LockStep, now: Date, shield: () -> Void, unshield: () -> Void,
                        schedule: (Date) throws -> Void, cancel: () -> Void) -> Outcome {
        switch step {
        case .clear:
            cancel()
            unshield()
        case .shield:
            cancel()
            shield()
        case .keepOpen:
            unshield()
        case .scheduleThenOpen(let end):
            do {
                try schedule(end)
            } catch {
                // Fail OPEN: the Amen (or the pause) opened the apps; a lock that can't promise to reopen must never
                // keep anyone out. The caller records the fault, so it's never silent.
                unshield()
                return .failedOpen((error as? LockFault) ?? .timerRefused, until: end)
            }
            unshield()
        }
        return .done
    }

    /// The interval Apple is asked to run so the apps lock at `relockAt` (see RelockTimer).
    static func timer(relockAt: Date, now: Date) -> RelockTimer {
        let end = min(max(relockAt.addingTimeInterval(backupDelay), now.addingTimeInterval(minimumInterval)),
                      now.addingTimeInterval(maximumInterval))
        // Whole minutes, rounded down: the warning lands 0–59 s after the window's end, inside monitorSlack.
        // (A leg that ends before the window gets no warning: its end re-arms the next leg.)
        let early = Int((end.timeIntervalSince(relockAt) / 60).rounded(.down))
        return RelockTimer(relockAt: relockAt, start: now, end: end, warningMinutes: early >= 1 ? early : nil)
    }

    /// The DeviceActivitySchedule's parts for a timer, in `calendar`'s time zone (the device's).
    static func scheduleParts(for timer: RelockTimer, calendar: Calendar)
        -> (start: DateComponents, end: DateComponents, warning: DateComponents?) {
        (calendar.dateComponents(scheduleComponents, from: timer.start),
         calendar.dateComponents(scheduleComponents, from: timer.end),
         timer.warningMinutes.map { DateComponents(minute: $0) })
    }

    /// The running timer still ends when it was started to end, and hasn't ended. Its end is wall-clock components, so
    /// a time-zone change moves it (hours early or late); this reads false and the next sync starts a new one. (A
    /// finished schedule iOS still lists, whose callback never came, reads false too.)
    static func timerIsCurrent(scheduledEnd: DateComponents?, expectedEnd: Date?, scheduledZone: String?,
                               calendar: Calendar, now: Date) -> Bool {
        guard let scheduledEnd, let expectedEnd, expectedEnd > now, scheduledZone == calendar.timeZone.identifier,
              let end = calendar.date(from: scheduledEnd) else { return false }
        return abs(end.timeIntervalSince(expectedEnd)) < 2
    }

    /// The monitor extension at the relock timer's warning (`intervalEnded` false) or end (true). The app may not be running.
    static func monitorAction(now: Date, active: Bool, unlockedUntil: Date?, pausedUntil: Date?, dailyKeyUntil: Date?,
                              intervalEnded: Bool) -> MonitorAction {
        switch plan(now: now, active: active, unlockedUntil: unlockedUntil, pausedUntil: pausedUntil,
                    dailyKeyUntil: dailyKeyUntil, slack: monitorSlack) {
        case .off:
            return .nothing
        case .shielded:
            return .shield
        case .open(let until):
            // At a warning the interval is still running and its end checks again.
            return intervalEnded ? .rearm(until: until) : .nothing
        }
    }

    /// Home's lock check. `verifiedRelock` is the end a running, current relock timer was confirmed for at the last sync;
    /// `fault` is set while the lock has failed open (by the app or the monitor extension).
    static func health(plan: ShieldPlan, accessLost: Bool, fault: LockFault?, verifiedRelock: Date?) -> LockHealth {
        if accessLost { return .accessOff }
        switch plan {
        case .off:
            return .off
        case .shielded:
            // A paused lock whose window is over is still open until the next sync locks it.
            if let fault { return .paused(fault) }
            return .locked
        case .open(let until):
            if let fault { return .paused(fault) }
            if let verifiedRelock, abs(verifiedRelock.timeIntervalSince(until)) < 1 { return .open(relocksAt: until) }
            return .paused(.timerRefused)
        }
    }

    /// Under Screen Time an unlock never ends sooner than 15 minutes from now.
    static func end(atLeastMinimumFrom now: Date, proposed: Date) -> Date {
        max(proposed, now.addingTimeInterval(minimumInterval))
    }

    /// The shortest unlock for a lock method: 15 minutes under Screen Time, 5 with Shortcuts.
    static func minimumWindowMinutes(for method: LockMethod) -> Int {
        method == .screenTime ? minimumMinutes : GateEngine.minimumWindowMinutes
    }

    /// The fixed window lengths offered for a lock method (Screen Time drops 5 minutes).
    static func windowOptions(for method: LockMethod) -> [Int] {
        UnlockChoice.presetMinutes.filter { $0 >= minimumWindowMinutes(for: method) }
    }

    static func effectiveWindowMinutes(_ minutes: Int, method: LockMethod) -> Int {
        method == .screenTime ? max(minimumMinutes, minutes) : minutes
    }

    static func emergencyMinutes(for method: LockMethod) -> Int {
        method == .screenTime ? max(minimumMinutes, GateEngine.emergencyMinutes) : GateEngine.emergencyMinutes
    }
}

/// What Strict Lock needs from Screen Time. StrictLockStore drives Apple's (ManagedSettings + DeviceActivityCenter);
/// the unit tests drive a simulated iPhone with Apple's rules, through the same RelockEngine code.
protocol ScreenTimeDevice: AnyObject {
    var calendar: Calendar { get }
    var isShielded: Bool { get }
    func shield()
    func unshield()
    /// The relock activity: starts (replacing) its non-repeating schedule. Throws a LockFault when Screen Time refuses.
    func startRelockActivity(start: DateComponents, end: DateComponents, warning: DateComponents?) throws
    func stopRelockActivity()
    /// The running relock activity's intervalEnd, nil when it isn't running.
    var relockActivityEnd: DateComponents? { get }
    /// "Open Pray to Scroll to lock your apps again", at `date` (nil cancels it).
    func remindToRelock(at date: Date?)
}

/// The relock timer and the monitor, against any ScreenTimeDevice. State lives in the app group (SharedStore), so the
/// app and the monitor extension see the same timer, fault and last relock.
enum RelockEngine {
    /// Starts the timer whose warning or end puts the shield back. Throws a LockFault when Screen Time refuses.
    static func schedule(at relockAt: Date, now: Date, device: ScreenTimeDevice, store: SharedStore) throws {
        let timer = ShieldPlanner.timer(relockAt: relockAt, now: now)
        let parts = ShieldPlanner.scheduleParts(for: timer, calendar: device.calendar)
        device.stopRelockActivity()
        do {
            try device.startRelockActivity(start: parts.start, end: parts.end, warning: parts.warning)
        } catch {
            clear(store)
            throw (error as? LockFault) ?? .timerRefused
        }
        store.relockScheduledFor = relockAt
        store.relockTimerEnd = timer.end
        store.relockTimeZone = device.calendar.timeZone.identifier
        // The safety net: shows only if iOS never calls the monitor (it withdraws this when it relocks).
        device.remindToRelock(at: relockAt.addingTimeInterval(ShieldPlanner.safetyReminderDelay))
    }

    /// One lock sync: plan → step → perform → the fault, its reminder and `screenTimeActive`. AppModel.syncLock runs it
    /// against its AppLock; the unit tests against a simulated iPhone.
    @discardableResult
    static func sync(now: Date, active: Bool, store: SharedStore, scheduledRelock: Date?, monitoring: Bool,
                     shield: () -> Void, unshield: () -> Void, isShielded: () -> Bool,
                     schedule: (Date) throws -> Void, cancel: () -> Void, remind: (Date?) -> Void) -> ShieldPlan {
        let plan = ShieldPlanner.plan(now: now, active: active, unlockedUntil: store.unlockedUntil,
                                      pausedUntil: store.pausedUntil, dailyKeyUntil: store.dailyKeyUntil)
        let step = ShieldPlanner.step(for: plan, now: now, scheduledRelock: scheduledRelock, monitoring: monitoring)
        let outcome = ShieldPlanner.perform(step, now: now, shield: shield, unshield: unshield, schedule: schedule, cancel: cancel)
        // Reminders: a new timer sets its safety reminder, a cancel withdraws it, a failure asks at the window's end.
        switch outcome {
        case .done:
            store.lockFault = step == .shield && !isShielded() ? .shieldOff : nil
        case .failedOpen(let fault, let until):
            store.lockFault = fault
            remind(until)
        }
        // While the lock is paused, a leftover Shortcuts automation (if any) asks for the prayer again after the window.
        store.screenTimeActive = active && store.lockFault == nil
        return plan
    }

    static func cancel(device: ScreenTimeDevice, store: SharedStore) {
        device.stopRelockActivity()
        device.remindToRelock(at: nil)
        clear(store)
    }

    /// A relock timer is running and still ends when it should.
    static func isMonitoring(device: ScreenTimeDevice, store: SharedStore, now: Date) -> Bool {
        ShieldPlanner.timerIsCurrent(scheduledEnd: device.relockActivityEnd, expectedEnd: store.relockTimerEnd,
                                     scheduledZone: store.relockTimeZone, calendar: device.calendar, now: now)
    }

    /// The monitor extension's intervalWillEndWarning (`intervalEnded` false) and intervalDidEnd (true).
    static func monitorFired(intervalEnded: Bool, now: Date, device: ScreenTimeDevice, store: SharedStore, hasSelection: Bool) {
        let settings = store.settings
        let active = settings.lockMethod == .screenTime && settings.gateEnabled && hasSelection
        switch ShieldPlanner.monitorAction(now: now, active: active, unlockedUntil: store.unlockedUntil,
                                           pausedUntil: store.pausedUntil, dailyKeyUntil: store.dailyKeyUntil,
                                           intervalEnded: intervalEnded) {
        case .nothing:
            return
        case .shield:
            device.stopRelockActivity()   // the rest of a warned interval has nothing left to do
            clear(store)
            device.shield()
            store.lastRelockAt = now
            store.lockFault = nil
            device.remindToRelock(at: nil)
        case .rearm(let until):
            do {
                try schedule(at: until, now: now, device: device, store: store)
            } catch {
                store.lockFault = .rearmFailed
                device.remindToRelock(at: until)
            }
        }
    }

    private static func clear(_ store: SharedStore) {
        store.relockScheduledFor = nil
        store.relockTimerEnd = nil
        store.relockTimeZone = nil
    }
}
#endif
