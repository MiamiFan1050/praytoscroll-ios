#if !NO_SCREEN_TIME
// (NO_SCREEN_TIME is set only by tools/run-unit-tests.sh, whose Mac Catalyst runner has no Screen Time frameworks.)
import DeviceActivity
import FamilyControls
import Foundation
import ManagedSettings

/// Screen Time plumbing shared by the app and its three extensions: the picked apps, the shield and the relock timer.
enum StrictLockStore {
    private static let selectionKey = "ak.strict.selection"
    static let relockActivity = DeviceActivityName("ak.strict.relock")
    static let managedStore = ManagedSettingsStore(named: ManagedSettingsStore.Name("prayToScroll"))

    private static var defaults: UserDefaults { SharedStore.shared.defaults }

    /// The apps, categories and sites picked in Apple's FamilyActivityPicker (opaque tokens, never names or usage).
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

    static var lockedCount: Int {
        let s = selection
        return s.applicationTokens.count + s.categoryTokens.count + s.webDomainTokens.count
    }

    static var hasSelection: Bool { lockedCount > 0 }

    /// Shields the picked apps, categories and sites.
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

    /// Starts the timer whose end puts the shield back (DeviceActivityMonitorExtension.intervalDidEnd).
    /// The caller only asks for windows of at least 15 minutes (ShieldPlanner). Throws when Screen Time refuses.
    static func scheduleRelock(at end: Date, now: Date = Date(), calendar: Calendar = .current) throws {
        let center = DeviceActivityCenter()
        center.stopMonitoring([relockActivity])
        let components: Set<Calendar.Component> = [.era, .year, .month, .day, .hour, .minute, .second]
        let schedule = DeviceActivitySchedule(intervalStart: calendar.dateComponents(components, from: now),
                                              intervalEnd: calendar.dateComponents(components, from: end),
                                              repeats: false)
        try center.startMonitoring(relockActivity, during: schedule)
        SharedStore.shared.relockScheduledFor = end
    }

    static func cancelRelock() {
        DeviceActivityCenter().stopMonitoring([relockActivity])
        SharedStore.shared.relockScheduledFor = nil
    }

    static var isMonitoring: Bool { DeviceActivityCenter().activities.contains(relockActivity) }

    /// The monitor extension when a window ends: shield again unless another window is still open.
    static func relockIfDue(now: Date = Date()) {
        let store = SharedStore.shared
        let settings = store.settings
        if let scheduled = store.relockScheduledFor, scheduled <= now.addingTimeInterval(ShieldPlanner.monitorSlack) {
            store.relockScheduledFor = nil
        }
        guard settings.lockMethod == .screenTime, settings.gateEnabled, hasSelection else { return }
        let plan = ShieldPlanner.plan(now: now, active: true, unlockedUntil: store.unlockedUntil,
                                      pausedUntil: store.pausedUntil, dailyKeyUntil: store.dailyKeyUntil,
                                      slack: ShieldPlanner.monitorSlack)
        if case .open = plan { return }
        shield()
    }
}
#endif
