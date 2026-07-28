import Foundation
import Security

final class KeychainService: @unchecked Sendable {
    static let shared = KeychainService()
    private init() {}

    private let service = "com.airdash.ios"
    private let apiKeyAccount = "airvpn.apikey"

    func saveAPIKey(_ key: String) throws {
        let data = Data(key.utf8)
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: apiKeyAccount,
            kSecValueData: data,
            kSecAttrAccessible: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        SecItemDelete(query as CFDictionary)

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw AppError.keychainError("Keychain write failed: \(status)")
        }
    }

    func loadAPIKey() -> String? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: apiKeyAccount,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func deleteAPIKey() {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: apiKeyAccount
        ]
        SecItemDelete(query as CFDictionary)
    }

    var hasAPIKey: Bool { loadAPIKey() != nil }
}
