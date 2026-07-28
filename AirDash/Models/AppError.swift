import Foundation

enum AppError: LocalizedError {
    case invalidKey
    case upstreamUnavailable
    case upstreamError(String)
    case decodingError
    case keychainError(String)
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .invalidKey:
            return String(localized: "error.invalid_key")
        case .upstreamUnavailable:
            return String(localized: "error.upstream_unavailable")
        case .upstreamError(let msg):
            return msg
        case .decodingError:
            return String(localized: "error.decoding")
        case .keychainError(let msg):
            return msg
        case .unknown(let msg):
            return msg
        }
    }
}
