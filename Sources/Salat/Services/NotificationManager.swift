import Foundation
import UserNotifications

struct PendingNotification {
    let id: String
    let title: String
    let body: String
    let date: Date
    let playsSound: Bool
}

/// Thin wrapper over UNUserNotificationCenter that replaces the whole pending set on each reschedule.
final class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let stopAzanAction = "STOP_AZAN"
    static let prayerCategory = "PRAYER"

    var onStopAzan: (() -> Void)?
    var onOpen: (() -> Void)?

    private var center: UNUserNotificationCenter? {
        // UNUserNotificationCenter traps when the process isn't inside an app bundle.
        Bundle.main.bundleIdentifier == nil ? nil : UNUserNotificationCenter.current()
    }

    func configure(stopTitle: String) {
        guard let center else { return }
        center.delegate = self
        let stop = UNNotificationAction(identifier: Self.stopAzanAction, title: stopTitle, options: [])
        let category = UNNotificationCategory(identifier: Self.prayerCategory, actions: [stop],
                                              intentIdentifiers: [], options: [])
        center.setNotificationCategories([category])
    }

    func requestAuthorization() async -> Bool {
        guard let center else { return false }
        return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        guard let center else { return .denied }
        return await center.notificationSettings().authorizationStatus
    }

    func reschedule(_ items: [PendingNotification]) {
        guard let center else { return }
        center.removeAllPendingNotificationRequests()
        let now = Date()
        // macOS keeps at most 64 pending requests per app.
        for item in items.filter({ $0.date > now }).sorted(by: { $0.date < $1.date }).prefix(60) {
            let content = UNMutableNotificationContent()
            content.title = item.title
            content.body = item.body
            content.categoryIdentifier = Self.prayerCategory
            content.interruptionLevel = .timeSensitive
            content.sound = item.playsSound ? .default : nil
            // Calendar triggers follow the wall clock, so they survive sleep; we reschedule on time zone changes.
            let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: item.date)
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            center.add(UNNotificationRequest(identifier: item.id, content: content, trigger: trigger))
        }
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .list, .sound])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let action = response.actionIdentifier
        DispatchQueue.main.async {
            if action == Self.stopAzanAction { self.onStopAzan?() } else { self.onOpen?() }
        }
        completionHandler()
    }
}
