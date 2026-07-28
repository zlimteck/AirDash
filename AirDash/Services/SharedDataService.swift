import Foundation
import WidgetKit

// Shared data model written by the app, read by the widget
struct SharedWidgetData: Codable {
    let currentIP: String?
    let isVPNActive: Bool
    let sessions: [SharedSession]
    let expirationDays: Int?
    let login: String?
    let updatedAt: Date

    struct SharedSession: Codable {
        let deviceName: String?
        let serverName: String?
        let serverCountryCode: String?
    }
}

enum SharedDataService {
    private static let suiteName = "group.com.airdash.ios"
    private static let key = "widgetData"

    static func write(
        currentIP: String?,
        isVPNActive: Bool,
        sessions: [AirVPNSession],
        user: AirVPNUser?
    ) {
        let shared = SharedWidgetData(
            currentIP: currentIP,
            isVPNActive: isVPNActive,
            sessions: sessions.map {
                SharedWidgetData.SharedSession(
                    deviceName: $0.deviceName,
                    serverName: $0.serverName,
                    serverCountryCode: $0.serverCountryCode
                )
            },
            expirationDays: user?.expirationDays,
            login: user?.login,
            updatedAt: .now
        )
        guard let defaults = UserDefaults(suiteName: suiteName),
              let data = try? JSONEncoder().encode(shared) else { return }
        defaults.set(data, forKey: key)
        WidgetCenter.shared.reloadAllTimelines()
    }

    static func read() -> SharedWidgetData? {
        guard let defaults = UserDefaults(suiteName: suiteName),
              let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode(SharedWidgetData.self, from: data)
        else { return nil }
        return decoded
    }
}
