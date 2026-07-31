import Foundation

struct ProfileHistoryEntry: Codable, Identifiable {
    let id: UUID
    let serverName: String
    let countryCode: String?
    let vpnProtocol: String
    let port: Int?
    let deviceName: String?
    let filename: String
    let content: String
    let date: Date
}

@MainActor
final class ProfileHistoryService {
    static let shared = ProfileHistoryService()
    private init() {}

    private let key = "profileHistory"
    private let maxEntries = 15

    var entries: [ProfileHistoryEntry] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([ProfileHistoryEntry].self, from: data)
        else { return [] }
        return decoded
    }

    func save(profile: GeneratedProfile, serverName: String, countryCode: String, vpnProtocol: VPNProtocol, port: Int?, deviceName: String?) {
        var current = entries
        current.removeAll { $0.serverName == serverName && $0.vpnProtocol == vpnProtocol.rawValue }
        let entry = ProfileHistoryEntry(
            id: UUID(),
            serverName: serverName,
            countryCode: countryCode as String?,
            vpnProtocol: vpnProtocol.rawValue,
            port: port,
            deviceName: deviceName,
            filename: profile.filename,
            content: profile.content,
            date: Date()
        )
        current.insert(entry, at: 0)
        if current.count > maxEntries { current = Array(current.prefix(maxEntries)) }
        if let data = try? JSONEncoder().encode(current) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    func entriesForServer(_ serverName: String) -> [ProfileHistoryEntry] {
        entries.filter { $0.serverName == serverName }
    }

    func remove(id: UUID) {
        var current = entries
        current.removeAll { $0.id == id }
        if let data = try? JSONEncoder().encode(current) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    func clearAll() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}
