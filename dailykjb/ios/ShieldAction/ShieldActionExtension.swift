import ManagedSettings
import UserNotifications

/// The shield's buttons. "Read now" can't open DailyKJB itself (Apple doesn't
/// allow a shield to), so it posts a notification that does, and closes the
/// app that was shielded. "Close" just closes it.
class ShieldActionExtension: ShieldActionDelegate {
    private func respond(_ action: ShieldAction, _ done: @escaping (ShieldActionResponse) -> Void) {
        switch action {
        case .primaryButtonPressed:
            let content = UNMutableNotificationContent()
            content.title = "Today's reading is waiting"
            content.body = "Tap to open DailyKJB. Your apps open again once you've read."
            content.sound = .default
            let request = UNNotificationRequest(
                identifier: "dailykjb.shield.read",
                content: content,
                trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
            )
            UNUserNotificationCenter.current().add(request) { _ in
                done(.close)
            }
        case .secondaryButtonPressed:
            done(.close)
        @unknown default:
            done(.close)
        }
    }

    override func handle(action: ShieldAction, for application: ApplicationToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        respond(action, completionHandler)
    }

    override func handle(action: ShieldAction, for webDomain: WebDomainToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        respond(action, completionHandler)
    }

    override func handle(action: ShieldAction, for category: ActivityCategoryToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        respond(action, completionHandler)
    }
}
