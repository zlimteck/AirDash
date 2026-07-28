import Foundation

actor AirVPNAPIClient {
    static let shared = AirVPNAPIClient()
    private init() {}

    private let baseURL = URL(string: "https://airvpn.org/api")!
    private let generatorURL = URL(string: "https://airvpn.org/api/generator/")!

    private let statusCache = TtlCache<AirVPNStatusResponse>(ttl: 60)
    private let userInfoCache = KeyedTtlCache<String, AirVPNUserInfoResponse>(ttl: 20)
    private let devicesCache = KeyedTtlCache<String, AirVPNDevicesResponse>(ttl: 60)

    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        return URLSession(configuration: config)
    }()

    // MARK: - Core

    private func post<T: Decodable>(_ service: String, body: [String: String] = [:]) async throws -> T {
        let url = baseURL.appendingPathComponent("\(service)/")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var payload = body
        payload["format"] = "json"
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await fetchWithRetry(request)

        guard let http = response as? HTTPURLResponse else {
            throw AppError.upstreamUnavailable
        }

        if http.statusCode == 401 || http.statusCode == 403 {
            throw AppError.invalidKey
        }
        guard (200..<300).contains(http.statusCode) else {
            throw AppError.upstreamUnavailable
        }

        // Check for API-level errors
        // AirVPN returns either {"result":"error","message":"..."} or just {"error":"Not authorized"}
        if let raw = try? JSONDecoder().decode([String: AnyCodable].self, from: data) {
            let result = raw["result"]?.value as? String
            let isError = result == "error" || (result == nil && raw["error"] != nil)
            if isError {
                let errorField = raw["error"]?.value as? String
                    ?? raw["message"]?.value as? String
                    ?? ""
                let lower = errorField.lowercased()
                if lower.contains("not authorized") || lower.contains("key") || lower.contains("auth") || lower.contains("user") || lower.contains("invalid") || errorField.isEmpty {
                    throw AppError.invalidKey
                }
                throw AppError.upstreamError(errorField)
            }
        }

        do {
            let decoder = JSONDecoder()
            return try decoder.decode(T.self, from: data)
        } catch {
            #if DEBUG
            if let raw = String(data: data, encoding: .utf8) {
                print("⚠️ Decoding error for \(T.self): \(error)")
                print("⚠️ Raw response: \(raw.prefix(500))")
            }
            #endif
            throw AppError.decodingError
        }
    }

    private func fetchWithRetry(_ request: URLRequest, retries: Int = 1) async throws -> (Data, URLResponse) {
        do {
            return try await session.data(for: request)
        } catch is CancellationError {
            throw CancellationError()
        } catch where retries > 0 {
            try await Task.sleep(for: .seconds(1))
            return try await fetchWithRetry(request, retries: retries - 1)
        } catch {
            throw AppError.upstreamUnavailable
        }
    }

    // MARK: - Public Endpoints

    func getStatus(forceRefresh: Bool = false) async throws -> AirVPNStatusResponse {
        if !forceRefresh, let cached = statusCache.get() { return cached }
        let result: AirVPNStatusResponse = try await post("status")
        statusCache.set(result)
        return result
    }

    func validateAPIKey(_ apiKey: String) async throws -> AirVPNUserInfoResponse {
        do {
            return try await post("userinfo", body: ["key": apiKey])
        } catch AppError.decodingError {
            throw AppError.invalidKey
        }
    }

    // MARK: - Authenticated Endpoints

    func getUserInfo(apiKey: String, forceRefresh: Bool = false) async throws -> AirVPNUserInfoResponse {
        let cacheKey = apiKey.prefix(8).description
        if !forceRefresh, let cached = userInfoCache.get(for: cacheKey) { return cached }
        do {
            let result: AirVPNUserInfoResponse = try await post("userinfo", body: ["key": apiKey])
            userInfoCache.set(result, for: cacheKey)
            return result
        } catch AppError.decodingError {
            throw AppError.invalidKey
        }
    }

    func getDevices(apiKey: String, forceRefresh: Bool = false) async throws -> AirVPNDevicesResponse {
        let cacheKey = apiKey.prefix(8).description
        if !forceRefresh, let cached = devicesCache.get(for: cacheKey) { return cached }
        let result: AirVPNDevicesResponse = try await post("devices", body: ["key": apiKey])
        devicesCache.set(result, for: cacheKey)
        return result
    }

    func addDevice(apiKey: String) async throws -> String {
        let cacheKey = apiKey.prefix(8).description
        let response = try await post("devices", body: ["key": apiKey, "action": "add"]) as AirVPNDevicesResponse
        devicesCache.invalidate(for: cacheKey)
        return response.devices.last?.id ?? ""
    }

    func deleteDevice(apiKey: String, deviceId: String) async throws {
        let cacheKey = apiKey.prefix(8).description
        let _: AirVPNDevicesResponse = try await post("devices", body: [
            "key": apiKey, "action": "delete", "id": deviceId
        ])
        devicesCache.invalidate(for: cacheKey)
    }

    func disconnectSession(apiKey: String, ip: String? = nil, server: String? = nil, device: String? = nil) async throws {
        let cacheKey = apiKey.prefix(8).description
        var body: [String: String] = ["key": apiKey]
        if let ip { body["ip"] = ip }
        if let server { body["server"] = server }
        if let device { body["device"] = device }
        let _: AirVPNBaseResponse = try await post("disconnect", body: body)
        userInfoCache.invalidate(for: cacheKey)
    }

    // MARK: - Profile Generator

    func generateProfile(
        apiKey: String,
        protocol vpnProtocol: VPNProtocol,
        serverName: String,
        port: Int? = nil,
        deviceName: String? = nil
    ) async throws -> GeneratedProfile {
        var components = URLComponents(url: generatorURL, resolvingAgainstBaseURL: false)!
        let selectedPort = port ?? vpnProtocol.defaultPort
        let protocolToken: String
        switch vpnProtocol {
        case .wireguard:
            protocolToken = "wireguard_1_udp_\(selectedPort)"
        case .openvpn:
            protocolToken = "openvpn_1_udp_\(selectedPort)"
        }

        var queryItems = [
            URLQueryItem(name: "servers", value: serverName),
            URLQueryItem(name: "protocols", value: protocolToken),
            URLQueryItem(name: "system", value: "linux")
        ]
        if let deviceName { queryItems.append(URLQueryItem(name: "device", value: deviceName)) }
        components.queryItems = queryItems

        guard let url = components.url else { throw AppError.upstreamUnavailable }

        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "API-KEY")

        let (data, response) = try await fetchWithRetry(request)

        guard let http = response as? HTTPURLResponse else { throw AppError.upstreamUnavailable }

        if http.statusCode == 401 || http.statusCode == 403 { throw AppError.invalidKey }
        guard (200..<300).contains(http.statusCode) else { throw AppError.upstreamUnavailable }

        let contentType = http.value(forHTTPHeaderField: "content-type") ?? ""
        let body = String(data: data, encoding: .utf8) ?? ""

        if contentType.contains("application/json") {
            if let parsed = try? JSONDecoder().decode([String: AnyCodable].self, from: data) {
                let msg = (parsed["error"]?.value as? String ?? parsed["result"]?.value as? String ?? "Generator error").lowercased()
                if msg.contains("key") || msg.contains("auth") { throw AppError.invalidKey }
                throw AppError.upstreamError(msg)
            }
            throw AppError.upstreamError("Generator error")
        }

        let disposition = http.value(forHTTPHeaderField: "content-disposition")
        let filename = parseFilename(from: disposition) ?? "AirVPN_\(serverName).\(vpnProtocol.fileExtension)"

        return GeneratedProfile(filename: filename, content: body, mimeType: "application/octet-stream")
    }

    private func parseFilename(from header: String?) -> String? {
        guard let header else { return nil }
        let pattern = #/filename="([^"]+)"/#
        return header.firstMatch(of: pattern).map { String($0.output.1) }
    }
}

// Minimal type-erased Codable for API-level error checking
struct AnyCodable: Codable {
    let value: Any

    init(_ value: Any) { self.value = value }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let v = try? container.decode(String.self) { value = v }
        else if let v = try? container.decode(Int.self) { value = v }
        else if let v = try? container.decode(Double.self) { value = v }
        else if let v = try? container.decode(Bool.self) { value = v }
        else { value = "" }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case let v as String: try container.encode(v)
        case let v as Int: try container.encode(v)
        case let v as Double: try container.encode(v)
        case let v as Bool: try container.encode(v)
        default: try container.encodeNil()
        }
    }
}
