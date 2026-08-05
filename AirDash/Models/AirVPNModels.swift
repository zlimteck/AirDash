import Foundation

// MARK: - Status

enum AirVPNHealth: String, Codable {
    case ok, warning, error
}

struct AirVPNServer: Codable, Identifiable, Hashable {
    var id: String { publicName }
    let publicName: String
    let countryName: String
    let countryCode: String
    let location: String
    let continent: String
    let bw: Double
    let bwMax: Double
    let users: Int
    let currentLoad: Double
    let health: AirVPNHealth
    let warning: String?
    let ipV4In1: String?
    let ipV4In2: String?
    let ipV6In1: String?

    enum CodingKeys: String, CodingKey {
        case publicName = "public_name"
        case countryName = "country_name"
        case countryCode = "country_code"
        case location, continent
        case bw, bwMax = "bw_max"
        case users
        case currentLoad = "currentload"
        case health, warning
        case ipV4In1 = "ip_v4_in1"
        case ipV4In2 = "ip_v4_in2"
        case ipV6In1 = "ip_v6_in1"
    }
}

struct AirVPNAggregate: Identifiable {
    var id: String { displayName }
    let displayName: String
    let serverBest: String?
    let bw: Double
    let bwMax: Double
    let users: Int
    let servers: Int
    let currentLoad: Double
    let health: AirVPNHealth
    let warning: String?
}

extension AirVPNAggregate: Codable {
    private enum CodingKeys: String, CodingKey {
        case publicName = "public_name"
        case countryName = "country_name"
        case continentKey = "continent"
        case serverBest = "server_best"
        case bw, bwMax = "bw_max"
        case users, servers
        case currentLoad = "currentload"
        case health, warning
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        // Countries use country_name, continents use continent, planets use public_name
        displayName = (try? c.decode(String.self, forKey: .publicName))
            ?? (try? c.decode(String.self, forKey: .countryName))
            ?? (try? c.decode(String.self, forKey: .continentKey))
            ?? "Unknown"
        serverBest = try? c.decode(String.self, forKey: .serverBest)
        bw = try c.decode(Double.self, forKey: .bw)
        bwMax = try c.decode(Double.self, forKey: .bwMax)
        users = try c.decode(Int.self, forKey: .users)
        servers = try c.decode(Int.self, forKey: .servers)
        currentLoad = try c.decode(Double.self, forKey: .currentLoad)
        health = try c.decode(AirVPNHealth.self, forKey: .health)
        warning = try? c.decode(String.self, forKey: .warning)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(displayName, forKey: .publicName)
        try c.encodeIfPresent(serverBest, forKey: .serverBest)
        try c.encode(bw, forKey: .bw)
        try c.encode(bwMax, forKey: .bwMax)
        try c.encode(users, forKey: .users)
        try c.encode(servers, forKey: .servers)
        try c.encode(currentLoad, forKey: .currentLoad)
        try c.encode(health, forKey: .health)
        try c.encodeIfPresent(warning, forKey: .warning)
    }
}

struct AirVPNStatusResponse: Codable {
    let result: String
    let servers: [AirVPNServer]
    let countries: [AirVPNAggregate]
    let continents: [AirVPNAggregate]
    let planets: [AirVPNAggregate]
}

// MARK: - User Info

struct AirVPNUser: Codable {
    let login: String
    let registerDate: String?
    let registerUnix: Int?
    let premium: Bool?
    let expirationUnix: Int?
    let expirationDate: String?
    let expirationDays: Int?
    let lastAttemptUnix: Int?
    let credits: Int?
    let connected: Bool?

    enum CodingKeys: String, CodingKey {
        case login
        case registerDate = "register_date"
        case registerUnix = "register_unix"
        case premium
        case expirationUnix = "expiration_unix"
        case expirationDate = "expiration_date"
        case expirationDays = "expiration_days"
        case lastAttemptUnix = "last_attempt_unix"
        case credits
        case connected
    }
}

struct AirVPNSession: Codable, Identifiable {
    var id: String { "\(vpnIP ?? "")-\(deviceName ?? "")-\(serverName ?? "")-\(connectedSinceUnix ?? 0)" }
    let vpnIP: String?
    let exitIP: String?
    let entryIP: String?
    let deviceName: String?
    let serverName: String?
    let serverCountry: String?
    let serverCountryCode: String?
    let serverContinent: String?
    let serverLocation: String?
    let serverBw: Int?
    let bytesRead: Int?
    let bytesWrite: Int?
    let connectedSinceUnix: Int?
    let connectedSinceDate: String?
    let speedRead: Int?
    let speedWrite: Int?

    enum CodingKeys: String, CodingKey {
        case vpnIP = "vpn_ip"
        case exitIP = "exit_ip"
        case entryIP = "entry_ip"
        case deviceName = "device_name"
        case serverName = "server_name"
        case serverCountry = "server_country"
        case serverCountryCode = "server_country_code"
        case serverContinent = "server_continent"
        case serverLocation = "server_location"
        case serverBw = "server_bw"
        case bytesRead = "bytes_read"
        case bytesWrite = "bytes_write"
        case connectedSinceUnix = "connected_since_unix"
        case connectedSinceDate = "connected_since_date"
        case speedRead = "speed_read"
        case speedWrite = "speed_write"
    }
}

struct AirVPNUserInfoResponse: Codable {
    let result: String
    let user: AirVPNUser
    let sessions: [AirVPNSession]?
    let connection: AirVPNSession?
}

// MARK: - Devices

struct AirVPNDevice: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let description: String?
    let status: String?
    let wireguardIPv4: String?
    let vpnLastFromUnix: Int?

    enum CodingKeys: String, CodingKey {
        case id, name, description, status
        case wireguardIPv4 = "wireguard_ipv4"
        case vpnLastFromUnix = "vpn_last_from_unix"
    }
}

struct AirVPNDevicesResponse: Codable {
    let result: String
    let devices: [AirVPNDevice]
}

// MARK: - DNS Lists

struct AirVPNDNSList: Codable, Identifiable, Hashable {
    var id: String { name }
    let name: String
    let displayName: String
    let description: String?
    let home: String?
    let lastUpdateUnix: Int?
    let nItems: Int?

    init(name: String, entry: AirVPNDNSListEntry) {
        self.name = name
        self.displayName = entry.name
        self.description = entry.description
        self.home = entry.home
        self.lastUpdateUnix = entry.lastUpdateUnix
        self.nItems = entry.nItems
    }
}

struct AirVPNDNSListEntry: Codable {
    let name: String
    let description: String?
    let home: String?
    let lastUpdateUnix: Int?
    let nItems: Int?

    enum CodingKeys: String, CodingKey {
        case name, description, home
        case lastUpdateUnix = "last_update_unix"
        case nItems = "n_items"
    }
}

struct AirVPNDNSListsResponse: Codable {
    let result: String
    let lists: [String: AirVPNDNSListEntry]

    var sortedLists: [AirVPNDNSList] {
        lists.map { AirVPNDNSList(name: $0.key, entry: $0.value) }
            .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }
}

// MARK: - Profile Generator

enum VPNProtocol: String, CaseIterable {
    case wireguard, openvpn

    var displayName: String {
        switch self {
        case .wireguard: "WireGuard"
        case .openvpn: "OpenVPN"
        }
    }

    var fileExtension: String {
        switch self {
        case .wireguard: "conf"
        case .openvpn: "ovpn"
        }
    }

    var ports: [Int] {
        switch self {
        case .wireguard: [1637, 47107, 51820]
        case .openvpn: [443, 1194, 2018, 80, 53]
        }
    }

    var defaultPort: Int {
        switch self {
        case .wireguard: 1637
        case .openvpn: 443
        }
    }
}

struct AirVPNBaseResponse: Codable {
    let result: String
}

struct GeneratedProfile {
    let filename: String
    let content: String
    let mimeType: String
}
