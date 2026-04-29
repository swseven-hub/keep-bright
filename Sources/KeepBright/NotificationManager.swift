import Foundation
import UserNotifications

final class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    private let center = UNUserNotificationCenter.current()

    override init() {
        super.init()
        center.delegate = self
    }

    func requestAuthorizationIfNeeded() {
        center.getNotificationSettings { [weak self] settings in
            guard settings.authorizationStatus == .notDetermined else {
                return
            }

            self?.center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
        }
    }

    func send(title: String, body: String, subtitle: String = "Keep Bright") {
        center.getNotificationSettings { [weak self] settings in
            guard let self else {
                return
            }

            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                self.deliver(title: title, subtitle: subtitle, body: body)
            case .notDetermined:
                self.center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
                    if granted {
                        self.deliver(title: title, subtitle: subtitle, body: body)
                    }
                }
            case .denied:
                return
            @unknown default:
                return
            }
        }
    }

    private func deliver(title: String, subtitle: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.subtitle = subtitle
        content.body = body
        content.sound = .default
        content.categoryIdentifier = "keep-bright-status"
        content.threadIdentifier = "keep-bright-status"
        content.summaryArgument = title

        if #available(macOS 12.0, *) {
            content.interruptionLevel = .active
        }

        let request = UNNotificationRequest(
            identifier: "keep-bright-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )

        center.add(request)
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list, .sound])
    }
}
