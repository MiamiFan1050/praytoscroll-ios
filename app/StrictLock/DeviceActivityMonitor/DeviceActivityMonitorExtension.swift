import DeviceActivity
import ManagedSettings

/// Puts the shield back when an unlock window (prayer, emergency pass, pause or Daily key) ends, even while the
/// person is still inside the app. The app runs one relock timer per window (StrictLockStore.scheduleRelock): a window
/// shorter than Apple's 15-minute minimum relocks on the interval's end WARNING, a long pause is covered in legs this
/// extension re-arms, and if Screen Time refuses a leg the app shows "Lock paused" and notifies at the window's end.
final class DeviceActivityMonitorExtension: DeviceActivityMonitor {
    override func intervalWillEndWarning(for activity: DeviceActivityName) {
        super.intervalWillEndWarning(for: activity)
        guard activity == StrictLockStore.relockActivity else { return }
        StrictLockStore.relockIfDue(intervalEnded: false)
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        guard activity == StrictLockStore.relockActivity else { return }
        StrictLockStore.relockIfDue(intervalEnded: true)
    }
}
