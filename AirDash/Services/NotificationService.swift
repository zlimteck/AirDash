import UserNotifications
import Foundation

enum NotificationService {
    private static let idPrefix = "airdash.expiry"
    private static let schedules: [(id: String, daysBefore: Int)] = [
        ("airdash.expiry.7d", 7),
        ("airdash.expiry.1d", 1)
    ]

    static func requestAuthorization() async {
        _ = try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound])
    }

    static func scheduleExpirationNotifications(expirationUnix: Int) async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized
           || settings.authorizationStatus == .provisional else { return }

        center.removePendingNotificationRequests(withIdentifiers: schedules.map(\.id))

        let expiration = Date(timeIntervalSince1970: TimeInterval(expirationUnix))
        let calendar = Calendar.current

        for schedule in schedules {
            guard let triggerDate = calendar.date(byAdding: .day, value: -schedule.daysBefore, to: expiration),
                  triggerDate > .now else { continue }

            let content = UNMutableNotificationContent()
            content.title = String(localized: LocalizedStringResource(
                stringLiteral: "notification.expiry.\(schedule.daysBefore == 1 ? "1d" : "7d").title"
            ))
            content.body = String(localized: LocalizedStringResource(
                stringLiteral: "notification.expiry.\(schedule.daysBefore == 1 ? "1d" : "7d").body"
            ))
            content.sound = .default

            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: triggerDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(identifier: schedule.id, content: content, trigger: trigger)
            try? await center.add(request)
        }
    }
}
