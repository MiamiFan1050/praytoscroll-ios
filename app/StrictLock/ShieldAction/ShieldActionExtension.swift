import ManagedSettings
import UserNotifications

/// Shield buttons. A shield can't open another app, so "Pray now" leaves a pending prayer and a tap-to-pray notification.
final class ShieldActionExtension: ShieldActionDelegate {
    override func handle(action: ShieldAction, for application: ApplicationToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        respond(to: action, completionHandler)
    }

    override func handle(action: ShieldAction, for webDomain: WebDomainToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        respond(to: action, completionHandler)
    }

    override func handle(action: ShieldAction, for category: ActivityCategoryToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        respond(to: action, completionHandler)
    }

    private func respond(to action: ShieldAction, _ completionHandler: @escaping (ShieldActionResponse) -> Void) {
        switch action {
        case .primaryButtonPressed:
            SharedStore.shared.setPendingGate(appID: "strict")
            let content = UNMutableNotificationContent()
            content.title = "Tap to pray"
            content.body = "Your prayer is ready. Hold Amen and your apps open."
            content.userInfo = ["url": AppLinks.prayDeepLink.absoluteString]
            content.interruptionLevel = .timeSensitive
            let request = UNNotificationRequest(identifier: "ak.strict.pray", content: content,
                                                trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false))
            UNUserNotificationCenter.current().add(request) { _ in completionHandler(.close) }
        case .secondaryButtonPressed:
            completionHandler(.close)
        @unknown default:
            completionHandler(.close)
        }
    }
}
