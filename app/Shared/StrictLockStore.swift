#if STRICT_LOCK
import DeviceActivity
import FamilyControls
import Foundation
import ManagedSettings

/// v1.1 Strict Lock: Screen Time shields shared by the app and its three extensions (compiled only with STRICT_LOCK).
enum StrictLockStore {
    private static let selectionKey = "ak.strict.selection"
    private static let enabledKey = "ak.strict.enabled"
    static let relockActivity = DeviceActivityName("ak.strict.relock")
    static let managedStore = ManagedSettingsStore(named: ManagedSettingsStore.Name("prayToScroll"))

    private static var defaults: UserDefaults { SharedStore.shared.defaults }

    static var selection: FamilyActivitySelection {
        get {
            guard let data = defaults.data(forKey: selectionKey),
                  let value = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) else { return FamilyActivitySelection() }
            return value
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) { defaults.set(data, forKey: selectionKey) }
        }
    }

    static var isEnabled: Bool {
        get { defaults.bool(forKey: enabledKey) }
        set { defaults.set(newValue, forKey: enabledKey) }
    }

    static var hasSelection: Bool {
        let s = selection
        return !s.applicationTokens.isEmpty || !s.categoryTokens.isEmpty || !s.webDomainTokens.isEmpty
    }

    /// Shields the chosen apps, categories and sites.
    static func shield() {
        let s = selection
        managedStore.shield.applications = s.applicationTokens.isEmpty ? nil : s.applicationTokens
        managedStore.shield.applicationCategories = s.categoryTokens.isEmpty ? nil : .specific(s.categoryTokens)
        managedStore.shield.webDomains = s.webDomainTokens.isEmpty ? nil : s.webDomainTokens
    }

    static func unshield() {
        managedStore.shield.applications = nil
        managedStore.shield.applicationCategories = nil
        managedStore.shield.webDomains = nil
    }

    /// After a prayer: lift the shields and have the monitor extension put them back when the window ends.
    /// DeviceActivity schedules must span at least 15 minutes, so a shorter window starts in the past and ends on time.
    static func unlock(until end: Date, now: Date = Date(), calendar: Calendar = .current) {
        guard isEnabled else { return }
        unshield()
        let center = DeviceActivityCenter()
        center.stopMonitoring([relockActivity])
        let start = min(now, end.addingTimeInterval(-15 * 60))
        let components: Set<Calendar.Component> = [.year, .month, .day, .hour, .minute, .second]
        let schedule = DeviceActivitySchedule(intervalStart: calendar.dateComponents(components, from: start),
                                              intervalEnd: calendar.dateComponents(components, from: end),
                                              repeats: false)
        do {
            try center.startMonitoring(relockActivity, during: schedule)
        } catch {
            // If monitoring can't start, fail closed on the next app launch instead of leaving apps open forever.
            defaults.set(end.timeIntervalSince1970, forKey: "ak.strict.relockAt")
        }
    }

    /// Called by the app on launch: re-shield if a relock was missed.
    static func enforce(now: Date = Date()) {
        guard isEnabled else { return }
        let unlockedUntil = [SharedStore.shared.unlockedUntil, SharedStore.shared.dailyKeyUntil].compactMap { $0 }.max()
        if let unlockedUntil, unlockedUntil > now { return }
        shield()
    }
}
#endif
