import Foundation
import WidgetKit

// Favorite server data shared with the widget
struct SharedServerData: Codable {
    let id: String
    let name: String
    let countryCode: String
    let location: String
    let load: Int
    let users: Int
    let isHealthy: Bool
    let latencyMs: Int?
}

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
    private static let serverNamesKey = "serverNames"

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

    static func writeServerNames(_ names: [String]) {
        guard let defaults = UserDefaults(suiteName: suiteName) else { return }
        defaults.set(names, forKey: serverNamesKey)
    }

    static func readServerNames() -> [String] {
        UserDefaults(suiteName: suiteName)?.stringArray(forKey: serverNamesKey) ?? []
    }

    static func writeDeviceNames(_ names: [String]) {
        guard let defaults = UserDefaults(suiteName: suiteName) else { return }
        defaults.set(names, forKey: "deviceNames")
    }

    static func readDeviceNames() -> [String] {
        UserDefaults(suiteName: suiteName)?.stringArray(forKey: "deviceNames") ?? []
    }

    static func writeFavoriteServers(_ servers: [SharedServerData]) {
        guard let defaults = UserDefaults(suiteName: suiteName),
              let data = try? JSONEncoder().encode(servers) else { return }
        defaults.set(data, forKey: "favoriteServersData")
        WidgetCenter.shared.reloadAllTimelines()
    }

    static func readFavoriteServers() -> [SharedServerData] {
        guard let defaults = UserDefaults(suiteName: suiteName),
              let data = defaults.data(forKey: "favoriteServersData"),
              let decoded = try? JSONDecoder().decode([SharedServerData].self, from: data)
        else { return [] }
        return decoded
    }

    static func writeBestServer(_ server: SharedServerData?) {
        guard let defaults = UserDefaults(suiteName: suiteName) else { return }
        guard let server, let data = try? JSONEncoder().encode(server) else {
            defaults.removeObject(forKey: "bestServerData")
            return
        }
        defaults.set(data, forKey: "bestServerData")
    }

    static func readBestServer() -> SharedServerData? {
        guard let defaults = UserDefaults(suiteName: suiteName),
              let data = defaults.data(forKey: "bestServerData"),
              let decoded = try? JSONDecoder().decode(SharedServerData.self, from: data)
        else { return nil }
        return decoded
    }

    static func read() -> SharedWidgetData? {
        guard let defaults = UserDefaults(suiteName: suiteName),
              let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode(SharedWidgetData.self, from: data)
        else { return nil }
        return decoded
    }
}
