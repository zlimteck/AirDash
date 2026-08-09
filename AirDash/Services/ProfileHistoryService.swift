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

    static let maxEntries = 15

    private let legacyKey = "profileHistory"

    private init() {
        migrateFromUserDefaultsIfNeeded()
        SpotlightService.indexRecentProfiles(entries)
    }

    private func migrateFromUserDefaultsIfNeeded() {
        guard KeychainService.shared.loadProfileHistory().isEmpty,
              let data = UserDefaults.standard.data(forKey: legacyKey),
              let decoded = try? JSONDecoder().decode([ProfileHistoryEntry].self, from: data),
              !decoded.isEmpty
        else { return }
        try? KeychainService.shared.saveProfileHistory(decoded)
        UserDefaults.standard.removeObject(forKey: legacyKey)
    }

    var entries: [ProfileHistoryEntry] {
        KeychainService.shared.loadProfileHistory()
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
        if current.count > Self.maxEntries { current = Array(current.prefix(Self.maxEntries)) }
        try? KeychainService.shared.saveProfileHistory(current)
        SpotlightService.indexRecentProfiles(current)
    }

    func entriesForServer(_ serverName: String) -> [ProfileHistoryEntry] {
        entries.filter { $0.serverName == serverName }
    }

    func remove(id: UUID) {
        var current = entries
        current.removeAll { $0.id == id }
        try? KeychainService.shared.saveProfileHistory(current)
        SpotlightService.indexRecentProfiles(current)
    }

    func clearAll() {
        KeychainService.shared.deleteProfileHistory()
        SpotlightService.indexRecentProfiles([])
    }
}
