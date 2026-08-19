import Foundation

actor AirVPNHistoryClient {
    static let shared = AirVPNHistoryClient()
    private init() {}

    private let baseURL = URL(string: "https://airvpn-api.zmtk.fr")!
    private let historyCache = KeyedTtlCache<String, ServerHistoryResponse>(ttl: 120)
    private let rankingCache = KeyedTtlCache<String, ServerRankingResponse>(ttl: 300)
    private let reliabilityCache = KeyedTtlCache<String, ServerReliabilityResponse>(ttl: 300)

    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        return URLSession(configuration: config)
    }()

    private func get<T: Decodable>(_ path: String, query: [URLQueryItem]) async throws -> T {
        guard var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false) else {
            throw AppError.unknown("Invalid history URL")
        }
        components.queryItems = query
        guard let url = components.url else {
            throw AppError.unknown("Invalid history URL")
        }
        let (data, response) = try await session.data(from: url)

        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw AppError.upstreamUnavailable
        }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw AppError.decodingError
        }
    }

    func history(server: String, range: HistoryRange = .oneDay, forceRefresh: Bool = false) async throws -> ServerHistoryResponse {
        let cacheKey = "\(server)|\(range.rawValue)"
        if !forceRefresh, let cached = historyCache.get(for: cacheKey) { return cached }
        let result: ServerHistoryResponse = try await get("servers/history", query: [
            URLQueryItem(name: "server", value: server),
            URLQueryItem(name: "range", value: range.rawValue)
        ])
        historyCache.set(result, for: cacheKey)
        return result
    }

    func ranking(window: HistoryRange = .oneHour, forceRefresh: Bool = false) async throws -> ServerRankingResponse {
        let cacheKey = window.rawValue
        if !forceRefresh, let cached = rankingCache.get(for: cacheKey) { return cached }
        let result: ServerRankingResponse = try await get("servers/ranking", query: [
            URLQueryItem(name: "sortBy", value: "load"),
            URLQueryItem(name: "window", value: window.rawValue)
        ])
        rankingCache.set(result, for: cacheKey)
        return result
    }

    func reliability(window: HistoryRange = .oneDay, forceRefresh: Bool = false) async throws -> ServerReliabilityResponse {
        let cacheKey = window.rawValue
        if !forceRefresh, let cached = reliabilityCache.get(for: cacheKey) { return cached }
        let result: ServerReliabilityResponse = try await get("servers/reliability", query: [
            URLQueryItem(name: "window", value: window.rawValue)
        ])
        reliabilityCache.set(result, for: cacheKey)
        return result
    }
}
