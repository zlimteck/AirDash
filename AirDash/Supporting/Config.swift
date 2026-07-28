import Foundation

// AirVPN API configuration — override via .xcconfig for CI/debug builds
enum APIConfig {
    static let baseURL = URL(string: "https://airvpn.org/api")!
    static let generatorURL = URL(string: "https://airvpn.org/api/generator/")!

    // Rate limit: AirVPN bans IPs exceeding 600 req/10 min
    // These TTL values (in seconds) are deliberately conservative
    enum CacheTTL {
        static let publicStatus: TimeInterval = 60
        static let userInfo: TimeInterval = 20
        static let devices: TimeInterval = 60
    }
}
