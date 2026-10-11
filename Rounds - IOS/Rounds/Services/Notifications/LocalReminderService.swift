import Foundation
import UserNotifications

/// Streak reminders as local notifications: scheduled on the device, so no server or push token.
struct LocalReminderService: ReminderService {
    private static let id = "streak-reminder"
    private static let trialID = "trial-reminder"

    func requestPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        switch await center.notificationSettings().authorizationStatus {
        case .authorized, .provisional, .ephemeral: return true
        case .denied: return false
        case .notDetermined: return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        @unknown default: return false
        }
    }

    func schedule(_ reminder: StreakReminder?) async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [Self.id])
        guard let reminder, reminder.fireAt > .now else { return }
        let content = UNMutableNotificationContent()
        content.title = reminder.title
        content.body = reminder.body
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: reminder.fireAt.timeIntervalSinceNow, repeats: false)
        try? await center.add(UNNotificationRequest(identifier: Self.id, content: content, trigger: trigger))
    }

    func scheduleTrialReminder(at date: Date, title: String, body: String) async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [Self.trialID])
        guard date > .now, await requestPermission() else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: date.timeIntervalSinceNow, repeats: false)
        try? await center.add(UNNotificationRequest(identifier: Self.trialID, content: content, trigger: trigger))
    }

    func announce(title: String, body: String) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        try? await UNUserNotificationCenter.current()
            .add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
    }
}
