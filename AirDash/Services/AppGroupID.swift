import Foundation
import Security

/// Resolves the App Group identifier this process was actually signed with,
/// instead of assuming it's always `group.com.airdash.ios`.
///
/// Some re-signing tools (e.g. SideStore) rename App Groups to avoid
/// colliding with one already registered under the sideloader's own Apple
/// ID, appending a suffix to the group ID itself (not just to Bundle IDs) —
/// `group.com.airdash.ios` becomes e.g. `group.com.airdash.ios.N5X9SZ4Q5B`.
/// A hardcoded group name then silently points the app and its extensions
/// at non-shared sandboxes: no crash, no entitlement error, UserDefaults and
/// Keychain reads just return nothing.
///
/// Deliberately uses only public API. An earlier version read the group
/// straight from the process's own code-signing entitlements via
/// `SecTaskCreateFromSelf`/`SecTaskCopyValueForEntitlement` — those are
/// treated as non-public by Apple despite being declared in Security
/// framework headers, and produced exactly the silent, crash-free failure
/// this file exists to avoid when called from inside the Widget extension's
/// sandbox. `FileManager.containerURL(forSecurityApplicationGroupIdentifier:)`
/// does the same job with a fully public, documented API: it returns `nil`
/// for a group identifier that isn't actually in this process's entitlements,
/// so trying the plain name first and a Team-ID-suffixed variant next is
/// enough to detect which one a re-signing tool actually used.
enum AppGroupID {
    private static let fallback = "group.com.airdash.ios"

    static let current: String = {
        if FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: fallback) != nil {
            return fallback
        }
        if let teamID = resolveTeamIDPrefix() {
            let suffixed = "\(fallback).\(teamID)"
            if FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: suffixed) != nil {
                return suffixed
            }
        }
        return fallback
    }()

    /// Same public-API Keychain probe `TunnelKeychainService` uses to discover
    /// `$(AppIdentifierPrefix)` at runtime: write a throwaway item with no
    /// explicit access group (Security.framework fills in the default,
    /// prefixed one), read its resolved `kSecAttrAccessGroup` back, and take
    /// the team ID prefix before the first dot.
    private static func resolveTeamIDPrefix() -> String? {
        let probeAccount = "airdash-appgroup-teamid-probe"
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
        return String(resolvedGroup[..<dotIndex])
    }
}
