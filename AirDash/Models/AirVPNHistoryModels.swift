import Foundation

struct ServerSnapshot: Codable, Identifiable {
    let serverName: String
    let countryName: String?
    let countryCode: String?
    let location: String?
    let loadPercent: Double
    let bwCurrent: Double?
    let bwMax: Double?
    let usersCount: Int
    let health: AirVPNHealth?
    let recordedAt: Int

    var id: Int { recordedAt }
    var date: Date { Date(timeIntervalSince1970: TimeInterval(recordedAt)) }

    enum CodingKeys: String, CodingKey {
        case serverName = "server_name"
        case countryName = "country_name"
        case countryCode = "country_code"
        case location
        case loadPercent = "load_percent"
        case bwCurrent = "bw_current"
        case bwMax = "bw_max"
        case usersCount = "users_count"
        case health
        case recordedAt = "recorded_at"
    }
}

struct ServerHistoryResponse: Codable {
    let server: String
    let range: String
    let points: [ServerSnapshot]
}

struct LatestServersResponse: Codable {
    let servers: [ServerSnapshot]
}

struct ServerRankingEntry: Codable, Identifiable {
    let serverName: String
    let countryName: String?
    let countryCode: String?
    let location: String?
    let avgLoadPercent: Double
    let sampleCount: Int

    var id: String { serverName }

    enum CodingKeys: String, CodingKey {
        case serverName = "server_name"
        case countryName = "country_name"
        case countryCode = "country_code"
        case location
        case avgLoadPercent = "avg_load_percent"
        case sampleCount = "sample_count"
    }
}

struct ServerRankingResponse: Codable {
    let sortBy: String
    let window: String
    let servers: [ServerRankingEntry]
}

struct ServerReliabilityEntry: Codable {
    let serverName: String
    let okPercent: Double
    let warningPercent: Double
    let errorPercent: Double
    let sampleCount: Int

    enum CodingKeys: String, CodingKey {
        case serverName = "server_name"
        case okPercent = "ok_percent"
        case warningPercent = "warning_percent"
        case errorPercent = "error_percent"
        case sampleCount = "sample_count"
    }
}

struct ServerReliabilityResponse: Codable {
    let window: String
    let servers: [ServerReliabilityEntry]
}

enum HistoryRange: String, CaseIterable, Identifiable {
    case oneHour = "1h"
    case oneDay = "24h"
    case sevenDays = "7d"
    case thirtyDays = "30d"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .oneHour:    String(localized: "history.range.1h")
        case .oneDay:     String(localized: "history.range.24h")
        case .sevenDays:  String(localized: "history.range.7d")
        case .thirtyDays: String(localized: "history.range.30d")
        }
    }
}
