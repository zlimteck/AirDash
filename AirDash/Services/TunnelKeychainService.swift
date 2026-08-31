import Foundation
import Security

/// Stores the full wg-quick config text (private key included) for the single
/// native tunnel profile, shared between the main app and the AirDashTunnel
/// Packet Tunnel Provider extension via a Keychain access group.
///
/// Deliberately separate from `KeychainService`: that service's items are
/// app-only (no access group) and wrong for something an extension process
/// must read. This file is compiled into both the AirDash and AirDashTunnel
/// targets (see project.yml `sources:`), not duplicated.
enum TunnelKeychainService {
    private static let service = "com.airdash.ios.tunnel"
    private static let account = "wireguard.tunnelconfig"
    private static let groupSuffix = "group.com.airdash.ios"

    static func save(wgQuickConfigText: String) throws {
        guard let group = accessGroup() else {
            throw AppError.keychainError("Could not resolve Keychain access group")
        }
        let data = Data(wgQuickConfigText.utf8)
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecAttrAccessGroup: group,
            kSecValueData: data,
            kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw AppError.keychainError("Tunnel keychain write failed: \(status)")
        }
    }

    static func load() -> String? {
        guard let group = accessGroup() else { return nil }
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecAttrAccessGroup: group,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete() {
        guard let group = accessGroup() else { return }
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecAttrAccessGroup: group
        ]
        SecItemDelete(query as CFDictionary)
    }

    /// `$(AppIdentifierPrefix)` (the Team ID) is only substituted inside entitlements
    /// plists by Xcode, never in Swift source — so it can't be hardcoded here. This
    /// discovers it at runtime with the standard Keychain-probe technique: write a
    /// throwaway item with no explicit access group (Security.framework fills in the
    /// default, prefixed one), read its resolved `kSecAttrAccessGroup` back, and reuse
    /// that prefix for the real shared-group queries above.
    private static func accessGroup() -> String? {
        if let cached = cachedPrefix { return cached + groupSuffix }

        let probeAccount = "airdash-team-id-probe"
        let probeQuery: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: probeAccount,
            kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlock,
            kSecReturnAttributes: true
        ]

        var result: AnyObject?
        var status = SecItemCopyMatching(probeQuery as CFDictionary, &result)
        if status == errSecItemNotFound {
            status = SecItemAdd(probeQuery as CFDictionary, &result)
        }
        guard status == errSecSuccess,
              let attributes = result as? [CFString: Any],
              let resolvedGroup = attributes[kSecAttrAccessGroup] as? String,
              let dotIndex = resolvedGroup.firstIndex(of: ".")
        else { return nil }

        let prefix = String(resolvedGroup[...dotIndex])
        cachedPrefix = prefix
        return prefix + groupSuffix
    }

    // Worst case on a race is redundant probe work, never corruption — SecItem* calls are thread-safe.
    nonisolated(unsafe) private static var cachedPrefix: String?
}
