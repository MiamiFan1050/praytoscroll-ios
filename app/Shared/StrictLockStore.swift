#if STRICT_LOCK && !NO_SCREEN_TIME
// STRICT_LOCK: only the project-strictlock.yml build has Screen Time. (NO_SCREEN_TIME is set only by
// tools/run-unit-tests.sh, whose Mac Catalyst runner has no Screen Time frameworks.)
import DeviceActivity
import FamilyControls
import Foundation
import ManagedSettings
import UserNotifications

/// Screen Time plumbing shared by the app and its three extensions: the picked apps, the shield and the relock timer.
/// The timer and monitor logic is RelockEngine (ShieldPlanner.swift), unit-tested against a simulated iPhone.
enum StrictLockStore {
    private static let selectionKey = "ak.strict.selection"
    /// The only DeviceActivity name Pray to Scroll uses: every new timer replaces it (Apple's limit is 20).
    static let relockActivity = DeviceActivityName("ak.strict.relock")
    static let managedStore = ManagedSettingsStore(named: ManagedSettingsStore.Name("prayToScroll"))
    static let relockReminderID = "ak.strict.relockReminder"

    private static var defaults: UserDefaults { SharedStore.shared.defaults }
    private static let device = AppleScreenTime()

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
    static func shield() { device.shield() }
    static func unshield() { device.unshield() }
    static var isShielded: Bool { device.isShielded }

    /// Starts the timer whose warning or end puts the shield back (DeviceActivityMonitorExtension).
    /// Throws a LockFault when Screen Time refuses.
    static func scheduleRelock(at end: Date, now: Date = Date()) throws {
        try RelockEngine.schedule(at: end, now: now, device: device, store: .shared)
    }

    static func cancelRelock() { RelockEngine.cancel(device: device, store: .shared) }

    static var isMonitoring: Bool { RelockEngine.isMonitoring(device: device, store: .shared, now: Date()) }

    /// The monitor extension at the relock timer's warning or end: shield again unless a window is still open.
    static func relockIfDue(intervalEnded: Bool, now: Date = Date()) {
        RelockEngine.monitorFired(intervalEnded: intervalEnded, now: now, device: device, store: .shared, hasSelection: hasSelection)
    }

    static func remindToRelock(at date: Date?) { device.remindToRelock(at: date) }
}

/// Apple's Screen Time as a ScreenTimeDevice.
private final class AppleScreenTime: ScreenTimeDevice {
    var calendar: Calendar { .current }

    var isShielded: Bool {
        let shield = StrictLockStore.managedStore.shield
        return shield.applications != nil || shield.applicationCategories != nil || shield.webDomains != nil
    }

    func shield() {
        let s = StrictLockStore.selection
        let store = StrictLockStore.managedStore
        store.shield.applications = s.applicationTokens.isEmpty ? nil : s.applicationTokens
        store.shield.applicationCategories = s.categoryTokens.isEmpty ? nil : .specific(s.categoryTokens)
        store.shield.webDomains = s.webDomainTokens.isEmpty ? nil : s.webDomainTokens
    }

    func unshield() {
        let store = StrictLockStore.managedStore
        store.shield.applications = nil
        store.shield.applicationCategories = nil
        store.shield.webDomains = nil
    }

    func startRelockActivity(start: DateComponents, end: DateComponents, warning: DateComponents?) throws {
        let schedule = DeviceActivitySchedule(intervalStart: start, intervalEnd: end, repeats: false, warningTime: warning)
        do {
            try DeviceActivityCenter().startMonitoring(StrictLockStore.relockActivity, during: schedule)
        } catch let error as DeviceActivityCenter.MonitoringError {
            switch error {
            case .excessiveActivities: throw LockFault.tooManyTimers
            case .unauthorized: throw LockFault.notAllowed
            default: throw LockFault.timerRefused   // intervalTooShort / intervalTooLong / invalidDateComponents
            }
        }
    }

    func stopRelockActivity() {
        DeviceActivityCenter().stopMonitoring([StrictLockStore.relockActivity])
    }

    var relockActivityEnd: DateComponents? {
        let center = DeviceActivityCenter()
        guard center.activities.contains(StrictLockStore.relockActivity) else { return nil }
        return center.schedule(for: StrictLockStore.relockActivity)?.intervalEnd
    }

    func remindToRelock(at date: Date?) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [StrictLockStore.relockReminderID])
        guard let date else { return }
        let content = UNMutableNotificationContent()
        content.title = "Lock your apps again"
        content.body = "Your time is up, but Screen Time couldn't lock your apps by itself. Open \(AppConstants.appName) to lock them."
        content.interruptionLevel = .active
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, date.timeIntervalSinceNow), repeats: false)
        center.add(UNNotificationRequest(identifier: StrictLockStore.relockReminderID, content: content, trigger: trigger)) { _ in }
    }
}
#endif
