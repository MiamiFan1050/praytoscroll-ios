import DeviceActivity
import ManagedSettings

/// Puts the shield back when an unlock window (prayer, emergency pass, pause or Daily key) ends, even while the
/// person is still inside the app. The app starts one relock timer per window (StrictLockStore.scheduleRelock).
final class DeviceActivityMonitorExtension: DeviceActivityMonitor {
    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        guard activity == StrictLockStore.relockActivity else { return }
        StrictLockStore.relockIfDue()
    }
}
