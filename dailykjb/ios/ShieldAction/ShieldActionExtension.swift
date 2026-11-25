import Foundation
import ManagedSettings
import UserNotifications

/// The shield's buttons. "Read now" opens Daily KJB at today's reading: from
/// iOS 26.5 the shield can open the app itself (.openParentalControlsApp);
/// before that it can't, so it posts a notification that does. Either way it
/// leaves a note in the app group ("shield_read_now") so the app goes straight
/// to the reading when it opens. "Close" just closes the shielded app.
class ShieldActionExtension: ShieldActionDelegate {
    private let defaults = UserDefaults(suiteName: "group.com.dailykjb.dailyKjb.shared")

    private func respond(_ action: ShieldAction, _ done: @escaping (ShieldActionResponse) -> Void) {
        switch action {
        case .primaryButtonPressed:
            defaults?.set(Date().timeIntervalSince1970, forKey: "shield_read_now")
            if #available(iOS 26.5, *) {
                done(.openParentalControlsApp)
                return
            }
            let content = UNMutableNotificationContent()
            content.title = "Today's reading is waiting"
            content.body = "Tap to open Daily KJB. Your apps open again once you've read."
            content.sound = .default
            content.userInfo = ["link": "dailykjb://read"]
            let request = UNNotificationRequest(
                identifier: "dailykjb.shield.read",
                content: content,
                trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
            )
            // Closed only once the notification is in, or iOS may end the extension first
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
