import Foundation
@preconcurrency import NetworkExtension

/// Owns the single native WireGuard tunnel profile Air-Dash manages via
/// NETunnelProviderManager/AirDashTunnel. Deliberately separate from `AppState`
/// (which must never be `@MainActor` on this project — see systemPatterns.md).
@MainActor
final class VPNTunnelManager: ObservableObject {
    static let shared = VPNTunnelManager()

    @Published private(set) var status: NEVPNStatus = .invalid

    private var manager: NETunnelProviderManager?
    private var statusObserver: NSObjectProtocol?

    private init() {
        Task { [weak self] in
            await self?.loadExistingManager()
        }
    }

    /// Re-syncs status from any previously saved tunnel — called at init, and safe
    /// to call again (e.g. on app foreground) since it's idempotent.
    func loadExistingManager() async {
        guard let managers = try? await loadAllManagers(), let existing = managers.first else { return }
        manager = existing
        status = existing.connection.status
        observeStatus(for: existing)
    }

    /// Saves (creating on first use, overwriting thereafter) the single managed tunnel
    /// profile. Never regenerates WireGuard keys — that's entirely the caller's concern;
    /// this only persists whatever wg-quick text it's given.
    func saveTunnel(wgQuickConfigText: String, serverName: String) async throws {
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
