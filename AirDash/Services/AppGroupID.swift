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
/// Reading the real value directly from the process's own code-signing
/// entitlements removes the dependency on any particular re-signing tool's
/// naming scheme. Falls back to the original literal if entitlement lookup
/// ever fails, so a normally-signed build (Xcode, TestFlight) is unaffected.
enum AppGroupID {
    private static let fallback = "group.com.airdash.ios"

    static let current: String = {
        guard let task = SecTaskCreateFromSelf(nil),
              let groups = SecTaskCopyValueForEntitlement(
                task, "com.apple.security.application-groups" as CFString, nil
              ) as? [String],
              let first = groups.first
        else { return fallback }
        return first
    }()
}
