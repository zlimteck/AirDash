import CoreSpotlight
import UniformTypeIdentifiers

enum SpotlightDomain {
    static let favoriteServer = "com.airdash.ios.favorite-server"
    static let recentProfile = "com.airdash.ios.recent-profile"
}

enum SpotlightItemID {
    static let serverPrefix = "server-"
    static let profilePrefix = "profile-"

    static func server(_ id: String) -> String { serverPrefix + id }
    static func profile(_ id: UUID) -> String { profilePrefix + id.uuidString }
}

@MainActor
enum SpotlightService {
    static func indexFavoriteServers(_ servers: [AirVPNServer]) {
        CSSearchableIndex.default().deleteSearchableItems(withDomainIdentifiers: [SpotlightDomain.favoriteServer]) { _ in }
        guard !servers.isEmpty else { return }
        let items = servers.map { server -> CSSearchableItem in
            let attributes = CSSearchableItemAttributeSet(contentType: .content)
            attributes.title = server.publicName
            attributes.contentDescription = "\(server.location) · \(server.countryName)"
            attributes.keywords = [server.publicName, server.countryName, server.location, "AirVPN", "VPN", "favorite"]
            return CSSearchableItem(
                uniqueIdentifier: SpotlightItemID.server(server.id),
                domainIdentifier: SpotlightDomain.favoriteServer,
                attributeSet: attributes
            )
        }
        CSSearchableIndex.default().indexSearchableItems(items)
    }

    static func indexRecentProfiles(_ entries: [ProfileHistoryEntry]) {
        CSSearchableIndex.default().deleteSearchableItems(withDomainIdentifiers: [SpotlightDomain.recentProfile]) { _ in }
        guard !entries.isEmpty else { return }
        let items = entries.map { entry -> CSSearchableItem in
            let attributes = CSSearchableItemAttributeSet(contentType: .content)
            attributes.title = entry.serverName
            let protocolLabel = entry.vpnProtocol.uppercased()
            attributes.contentDescription = [protocolLabel, entry.deviceName].compactMap { $0 }.joined(separator: " · ")
            attributes.keywords = [entry.serverName, protocolLabel, entry.deviceName, "profile", "VPN"].compactMap { $0 }
            return CSSearchableItem(
                uniqueIdentifier: SpotlightItemID.profile(entry.id),
                domainIdentifier: SpotlightDomain.recentProfile,
                attributeSet: attributes
            )
        }
        CSSearchableIndex.default().indexSearchableItems(items)
    }
}
