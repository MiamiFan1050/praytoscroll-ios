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
    /// Start the relock timer FIRST, and only lift the shield once it's running.
    case scheduleThenOpen(until: Date)
}

/// Pure Strict Lock logic, shared by the app, the DeviceActivity monitor extension and the unit tests.
///
/// Apple's DeviceActivity schedules must span at least 15 minutes. A shorter window would need a schedule that
/// starts in the past, which we can't prove relocks on time, so under Screen Time every window is at least
/// 15 minutes and a relock timer is never started for less. If one can't be started, the apps stay shielded:
/// a relock must never fail silently.
enum ShieldPlanner {
    static let minimumMinutes = 15
    static var minimumInterval: TimeInterval { TimeInterval(minimumMinutes * 60) }
    /// The monitor's `intervalDidEnd` can arrive a little early; a window that ends within this is treated as over.
    static let monitorSlack: TimeInterval = 60

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

    /// `scheduledRelock` is the end the running relock timer was started for; `monitoring` says it's still running.
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
            // A new end needs a new timer, and Apple won't run one shorter than 15 minutes.
            if until.timeIntervalSince(now) >= minimumInterval - 1 {
                return .scheduleThenOpen(until: until)
            }
            // The timer for this window was lost and too little time is left to start another: lock now.
            return .shield
        }
    }

    /// Carries out one step. Returns false when the relock timer couldn't start, in which case the apps stay shielded.
    /// (AppModel runs it against Apple's shields; the tests run it against a simulated device.)
    @discardableResult
    static func perform(_ step: LockStep, now: Date, shield: () -> Void, unshield: () -> Void,
                        schedule: (Date) throws -> Void, cancel: () -> Void) -> Bool {
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
                shield()
                return false
            }
            unshield()
        }
        return true
    }

    /// Under Screen Time an unlock never ends sooner than 15 minutes from now.
    static func end(atLeastMinimumFrom now: Date, proposed: Date) -> Date {
        max(proposed, now.addingTimeInterval(minimumInterval))
    }

    /// The window lengths offered for a lock method (Screen Time drops 5 minutes).
    static func windowOptions(for method: LockMethod) -> [Int] {
        method == .screenTime ? GateEngine.windowOptions.filter { $0 >= minimumMinutes } : GateEngine.windowOptions
    }

    static func effectiveWindowMinutes(_ minutes: Int, method: LockMethod) -> Int {
        method == .screenTime ? max(minimumMinutes, minutes) : minutes
    }

    static func emergencyMinutes(for method: LockMethod) -> Int {
        method == .screenTime ? max(minimumMinutes, GateEngine.emergencyMinutes) : GateEngine.emergencyMinutes
    }
}
