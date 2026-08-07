import Foundation
import Security

final class KeychainService: @unchecked Sendable {
    static let shared = KeychainService()
    private init() {}

    private let service = "com.airdash.ios"
    private let apiKeyAccount = "airvpn.apikey"
    private let accountsAccount = "airvpn.accounts"
    private let profileHistoryAccount = "airvpn.profilehistory"

    // MARK: - Generic Codable storage

    private func saveCodable<T: Codable>(_ value: T, account: String) throws {
        let data = try JSONEncoder().encode(value)
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecValueData: data,
            kSecAttrAccessible: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        SecItemDelete(query as CFDictionary)

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw AppError.keychainError("Keychain write failed: \(status)")
        }
    }

    private func loadCodable<T: Codable>(account: String) -> T? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    private func deleteItem(account: String) {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account
        ]
        SecItemDelete(query as CFDictionary)
    }

    // MARK: - Legacy single-key API (kept for migration)

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

    // MARK: - Multi-account API

    func saveAccounts(_ accounts: [Account]) throws {
        try saveCodable(accounts, account: accountsAccount)
    }

    func loadAccounts() -> [Account] {
        loadCodable(account: accountsAccount) ?? []
    }

    func deleteAllAccounts() {
        deleteItem(account: accountsAccount)
    }

    // MARK: - Profile history

    func saveProfileHistory(_ entries: [ProfileHistoryEntry]) throws {
        try saveCodable(entries, account: profileHistoryAccount)
    }

    func loadProfileHistory() -> [ProfileHistoryEntry] {
        loadCodable(account: profileHistoryAccount) ?? []
    }

    func deleteProfileHistory() {
        deleteItem(account: profileHistoryAccount)
    }
}
