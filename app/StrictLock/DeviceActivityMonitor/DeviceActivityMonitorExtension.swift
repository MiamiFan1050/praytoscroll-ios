import DeviceActivity
import ManagedSettings

/// Re-locks the shielded apps when an unlock window ends.
final class DeviceActivityMonitorExtension: DeviceActivityMonitor {
    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        guard activity == StrictLockStore.relockActivity, StrictLockStore.isEnabled else { return }
        StrictLockStore.shield()
    }
}
