import Foundation
@preconcurrency import NetworkExtension
import ActivityKit

/// Owns the single native WireGuard tunnel profile Air-Dash manages via
/// NETunnelProviderManager/AirDashTunnel. Deliberately separate from `AppState`
/// (which must never be `@MainActor` on this project — see systemPatterns.md).
@MainActor
final class VPNTunnelManager: ObservableObject {
    static let shared = VPNTunnelManager()

    @Published private(set) var status: NEVPNStatus = .invalid {
        didSet { handleStatusChange() }
    }
    @Published private(set) var connectedServerName: String?
    private var connectedCountryCode: String?

    private var manager: NETunnelProviderManager?
    private var statusObserver: NSObjectProtocol?

    private var sessionStartUnix: Int?
    private var activity: Activity<VPNSessionAttributes>?

    private init() {
        // Re-adopt a Live Activity that's still running from a previous process
        // (e.g. app was killed while connected) instead of starting a duplicate.
        activity = Activity<VPNSessionAttributes>.activities.first
        Task { [weak self] in
            await self?.loadExistingManager()
        }
    }

    /// Re-syncs status from any previously saved tunnel — called at init, and safe
    /// to call again (e.g. on app foreground) since it's idempotent.
    func loadExistingManager() async {
        guard let managers = try? await loadAllManagers(), let existing = managers.first else { return }
        manager = existing
        connectedServerName = (existing.protocolConfiguration as? NETunnelProviderProtocol)?.serverAddress
        observeStatus(for: existing)
        status = existing.connection.status
    }

    /// Saves (creating on first use, overwriting thereafter) the single managed tunnel
    /// profile. Never regenerates WireGuard keys — that's entirely the caller's concern;
    /// this only persists whatever wg-quick text it's given.
    func saveTunnel(wgQuickConfigText: String, serverName: String, countryCode: String? = nil) async throws {
        try TunnelKeychainService.save(wgQuickConfigText: wgQuickConfigText)

        let target = manager ?? NETunnelProviderManager()

        let proto = NETunnelProviderProtocol()
        proto.providerBundleIdentifier = "com.airdash.ios.tunnel"
        proto.serverAddress = serverName
        target.protocolConfiguration = proto
        let port = Self.endpointPort(fromWgQuickConfig: wgQuickConfigText) ?? "?"
        target.localizedDescription = "AirDash_\(serverName)_WireGuard_\(port)_AirVPN"
        target.isEnabled = true

        try await save(target)
        try await reload(target)

        manager = target
        observeStatus(for: target)
        connectedServerName = serverName
        connectedCountryCode = countryCode
        status = target.connection.status
    }

    /// Pulls the port out of the wg-quick text's `Endpoint = host:port` line, so the
    /// tunnel's display name reflects the real port even when the user picked "default".
    private static func endpointPort(fromWgQuickConfig text: String) -> String? {
        for line in text.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.lowercased().hasPrefix("endpoint") else { continue }
            guard let equalsIndex = trimmed.firstIndex(of: "=") else { continue }
            let value = trimmed[trimmed.index(after: equalsIndex)...].trimmingCharacters(in: .whitespaces)
            guard let colonIndex = value.lastIndex(of: ":") else { continue }
            return String(value[value.index(after: colonIndex)...])
        }
        return nil
    }

    func connect() async throws {
        guard let manager else { throw VPNTunnelManagerError.noSavedTunnel }
        try manager.connection.startVPNTunnel()
    }

    func disconnect() async {
        manager?.connection.stopVPNTunnel()
    }

    /// Waits for an in-flight disconnect to actually finish, so a caller that wants to
    /// switch servers can safely start a new tunnel right after without the OS silently
    /// ignoring `startVPNTunnel()` because the previous session is still tearing down.
    func waitUntilDisconnected(timeout: TimeInterval = 5) async {
        let deadline = Date().addingTimeInterval(timeout)
        while status == .connected || status == .connecting || status == .disconnecting || status == .reasserting {
            if Date() >= deadline { break }
            try? await Task.sleep(for: .milliseconds(200))
        }
    }

    // MARK: - Live Activity (lock screen / Dynamic Island)

    private func handleStatusChange() {
        if status == .connected {
            if sessionStartUnix == nil {
                sessionStartUnix = Int(Date().timeIntervalSince1970)
            }
        } else if status == .disconnected || status == .invalid {
            sessionStartUnix = nil
        }
        syncLiveActivity()
    }

    /// Starts, updates, or ends the Live Activity to mirror `status`. A no-op if the
    /// user disabled Live Activities system-wide (Settings > Face ID & Code) — the
    /// tunnel itself is unaffected either way.
    private func syncLiveActivity() {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let activityStatus: VPNActivityStatus
        switch status {
        case .connecting:     activityStatus = .connecting
        case .connected:      activityStatus = .connected
        case .reasserting:    activityStatus = .reasserting
        case .disconnecting:  activityStatus = .disconnecting
        default:
            guard let activity else { return }
            let content = ActivityContent(state: activity.content.state, staleDate: nil)
            // Activity<Attributes> isn't Sendable-checked by the compiler even though
            // it's safe to call from any context (an OS-managed handle) — same
            // rationale as `UncheckedSendableBox` below for NetworkExtension's
            // non-Sendable completion-handler payloads.
            let box = UncheckedSendableBox(value: activity)
            Task { await box.value.end(content, dismissalPolicy: .immediate) }
            self.activity = nil
            return
        }

        let state = VPNSessionAttributes.ContentState(status: activityStatus, connectedSinceUnix: sessionStartUnix)
        let content = ActivityContent(state: state, staleDate: nil)

        if let activity {
            let box = UncheckedSendableBox(value: activity)
            Task { await box.value.update(content) }
        } else if let name = connectedServerName {
            let attributes = VPNSessionAttributes(serverName: name, countryCode: connectedCountryCode)
            activity = try? Activity.request(attributes: attributes, content: content, pushType: nil)
        }
    }

    private func observeStatus(for manager: NETunnelProviderManager) {
        if let statusObserver {
            NotificationCenter.default.removeObserver(statusObserver)
        }
        statusObserver = NotificationCenter.default.addObserver(
            forName: .NEVPNStatusDidChange,
            object: manager.connection,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.status = manager.connection.status
            }
        }
    }

    // MARK: - Completion-handler → async bridges
    // NetworkExtension's preference APIs are completion-handler based; wrapped here
    // explicitly rather than assumed to have async overloads.

    private func loadAllManagers() async throws -> [NETunnelProviderManager] {
        let box: UncheckedSendableBox<[NETunnelProviderManager]> = try await withCheckedThrowingContinuation { continuation in
            NETunnelProviderManager.loadAllFromPreferences { managers, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: UncheckedSendableBox(value: managers ?? []))
                }
            }
        }
        return box.value
    }

    private func save(_ manager: NETunnelProviderManager) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            manager.saveToPreferences { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    private func reload(_ manager: NETunnelProviderManager) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            manager.loadFromPreferences { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }
}

/// Escape hatch for bridging NetworkExtension's non-Sendable completion-handler
/// payloads across a `CheckedContinuation` under Swift 6 strict concurrency —
/// the callback always runs before/independently of the resuming task reading
/// the value, so there's no real race, just a type the framework hasn't annotated.
private struct UncheckedSendableBox<T>: @unchecked Sendable {
    let value: T
}

enum VPNTunnelManagerError: LocalizedError {
    case noSavedTunnel

    var errorDescription: String? {
        switch self {
        case .noSavedTunnel:
            return String(localized: "tunnel.error.no_saved_tunnel")
        }
    }
}
