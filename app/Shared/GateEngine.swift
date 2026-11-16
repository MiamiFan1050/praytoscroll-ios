import Foundation

enum GateDecision: Equatable, Sendable {
    /// Let the person straight through. `until` is when the current unlock ends (nil when not time-bound).
    case allow(until: Date?, reason: AllowReason)
    /// The person tapped "Test my gate": confirm the automation works instead of asking for a prayer.
    case verifyTest
    /// Bring PrayToScroll to the foreground for a prayer.
    case requirePrayer
}

enum AllowReason: String, Equatable, Sendable {
    case gateOff, paused, notGated, unlocked, dailyKey, launchPass, grace
}

/// Everything the gate needs to decide, read from the shared app-group store.
struct GateSnapshot: Equatable, Sendable {
    var gateEnabled: Bool
    var gatedAppIDs: Set<String>
    var customApps: [GatedApp]
    var unlockedUntil: Date?
    var pausedUntil: Date?
    var dailyKeyUntil: Date?
    /// Per-app 30 s pass set right before PrayToScroll reopens an app ("Continue to Instagram", emergency pass).
    var launchPasses: [String: Date] = [:]
    /// Per-app "Test my gate" requests (when the test started).
    var testPending: [String: Date] = [:]
}

/// Pure decision logic for the Prayer Gate (used by the App Intents, the app and the tests).
enum GateEngine {
    /// The id "Pray First" sends when its App field is left empty: ONE automation for all your apps.
    /// It can't tell which app opened, so it honours any app's launch pass or test.
    static let anyAppID = "app"

    /// The shortest window in Shortcuts mode (Screen Time's floor in v1.1 is 15).
    static let minimumWindowMinutes = 5
    static let defaultWindowMinutes = 15
    static let emergencyMinutes = 5
    static let defaultDailyResetHour = 4
    /// PrayToScroll reopening an app must never trigger the gate again.
    static let launchPassSeconds: TimeInterval = 30
    /// An app reopened within 20 s of its window ending stays open (screenshot editor, app switcher bounce).
    static let graceSeconds: TimeInterval = 20
    /// A "Test my gate" request is honoured for this long.
    static let testWindowSeconds: TimeInterval = 90

    static func isUnlocked(now: Date, unlockedUntil: Date?) -> Bool {
        guard let unlockedUntil else { return false }
        return now < unlockedUntil
    }

    static func remaining(now: Date, unlockedUntil: Date?) -> TimeInterval {
        guard let unlockedUntil else { return 0 }
        return max(0, unlockedUntil.timeIntervalSince(now))
    }

    /// Extends (never shortens) the unlock window. Windows are absolute instants, so they work across midnight.
    static func unlock(from now: Date, minutes: Int, existing: Date?) -> Date {
        let proposed = now.addingTimeInterval(TimeInterval(max(1, minutes)) * 60)
        guard let existing, existing > proposed else { return proposed }
        return existing
    }

    /// Extends (never shortens) the unlock window to `proposed`.
    static func unlock(from now: Date, until proposed: Date, existing: Date?) -> Date {
        guard let existing, existing > proposed else { return proposed }
        return existing
    }

    /// The next reset instant for the Daily key: today at `resetHour` if that's still ahead, else tomorrow.
    static func dailyKeyUntil(from now: Date, resetHour: Int, calendar: Calendar) -> Date {
        let hour = min(23, max(0, resetHour))
        let todayReset = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: now) ?? now
        if todayReset > now { return todayReset }
        return calendar.date(byAdding: .day, value: 1, to: todayReset) ?? now.addingTimeInterval(86_400)
    }

    static func decide(appID: String, now: Date, snapshot: GateSnapshot) -> GateDecision {
        let key = canonicalID(appID, customApps: snapshot.customApps)
        let anyApp = key == anyAppID

        // A pending test always wins, so "Test my gate" works even while unlocked.
        if testedApp(key, now: now, snapshot: snapshot) != nil {
            return .verifyTest
        }
        if !snapshot.gateEnabled { return .allow(until: nil, reason: .gateOff) }
        if let paused = snapshot.pausedUntil, now < paused { return .allow(until: paused, reason: .paused) }

        // A known app the person removed from their list passes through. Unknown or generic ids are gated,
        // because the person built an automation for them on purpose.
        if AppCatalog.isKnown(id: key, customApps: snapshot.customApps), !snapshot.gatedAppIDs.contains(key) {
            return .allow(until: nil, reason: .notGated)
        }
        if let pass = anyApp ? snapshot.launchPasses.values.filter({ now < $0 }).max() : snapshot.launchPasses[key],
           now < pass {
            return .allow(until: pass, reason: .launchPass)
        }
        if let daily = snapshot.dailyKeyUntil, now < daily {
            return .allow(until: daily, reason: .dailyKey)
        }
        if isUnlocked(now: now, unlockedUntil: snapshot.unlockedUntil) {
            return .allow(until: snapshot.unlockedUntil, reason: .unlocked)
        }
        if let ended = snapshot.unlockedUntil, now >= ended, now.timeIntervalSince(ended) < graceSeconds {
            return .allow(until: ended.addingTimeInterval(graceSeconds), reason: .grace)
        }
        return .requirePrayer
    }

    /// The app whose "Test my gate" this run answers: the app itself, or (for the all-apps automation) the most
    /// recent test still open.
    static func testedApp(_ key: String, now: Date, snapshot: GateSnapshot) -> String? {
        func fresh(_ started: Date) -> Bool { now.timeIntervalSince(started) >= 0 && now.timeIntervalSince(started) < testWindowSeconds }
        if key == anyAppID {
            return snapshot.testPending.filter { fresh($0.value) }.max { $0.value < $1.value }?.key
        }
        return snapshot.testPending[key].map(fresh) == true ? key : nil
    }

    /// Maps aliases ("twitter", "fb") to catalog ids so passes and tests line up.
    static func canonicalID(_ appID: String, customApps: [GatedApp]) -> String {
        AppCatalog.app(id: appID, customApps: customApps)?.id ?? appID.lowercased()
    }

    /// The emergency pass resets at local midnight: one per calendar day.
    static func canUseEmergencyPass(now: Date, lastUsed: Date?, calendar: Calendar) -> Bool {
        guard let lastUsed else { return true }
        return DayKey(lastUsed, calendar: calendar) != DayKey(now, calendar: calendar)
    }

    static func nextEmergencyPassDate(now: Date, lastUsed: Date?, calendar: Calendar) -> Date? {
        guard !canUseEmergencyPass(now: now, lastUsed: lastUsed, calendar: calendar) else { return nil }
        return DayKey(now, calendar: calendar).adding(days: 1, calendar: calendar).startDate(in: calendar)
    }

    /// "12:34" style countdown text.
    static func countdownText(_ interval: TimeInterval) -> String {
        let total = max(0, Int(interval.rounded(.up)))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 { return String(format: "%d:%02d:%02d", hours, minutes, seconds) }
        return String(format: "%d:%02d", minutes, seconds)
    }
}

/// Per-app setup status shown in the gate checklist.
enum GateSetupStatus: Equatable, Sendable {
    case notSetUp
    case waitingForFirstOpen
    case protected(lastFired: Date)
    case silent(lastFired: Date)

    static let silentAfter: TimeInterval = 3 * 86_400

    static func status(lastFired: Date?, markedSetUpAt: Date?, now: Date) -> GateSetupStatus {
        if let lastFired {
            return now.timeIntervalSince(lastFired) > silentAfter ? .silent(lastFired: lastFired) : .protected(lastFired: lastFired)
        }
        return markedSetUpAt == nil ? .notSetUp : .waitingForFirstOpen
    }

    var isProtected: Bool {
        if case .protected = self { return true }
        return false
    }
}
