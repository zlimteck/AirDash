#if VPN_ENABLED
import AppIntents
import UIKit

// MARK: - Headless connect

private enum ShortcutConnectError: LocalizedError {
    case notSignedIn
    case unknownServer(String)
    case noServerChosen
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .notSignedIn:
            return "Sign in to AirDash first."
        case .unknownServer(let name):
            return "Server \(name) was not found."
        case .noServerChosen:
            return "No server is set for this shortcut. Open it in the Shortcuts app and choose a server."
        case .failed(let message):
            return message
        }
    }
}

/// Connects the native tunnel to a server without any UI: same chain as the Network
/// tab's quick connect (generate a WireGuard profile through the API, save it, start
/// the tunnel), but runnable from an intent.
@MainActor
private enum ShortcutConnector {
    static func connect(serverName: String, deviceName requestedDevice: String?, port: Int?) async throws {
        // The API key lives in a WhenUnlocked keychain item, so this also fails
        // while the device is locked.
        let accounts = KeychainService.shared.loadAccounts()
        let activeId = UserDefaults.standard.string(forKey: "activeAccountId")
        guard let account = accounts.first(where: { $0.id == activeId }) ?? accounts.first else {
            throw ShortcutConnectError.notSignedIn
        }
        let apiKey = account.apiKey

        do {
            let status = try await AirVPNAPIClient.shared.getStatus()
            guard let server = status.servers.first(where: { $0.publicName.lowercased() == serverName.lowercased() }) else {
                throw ShortcutConnectError.unknownServer(serverName)
            }

            let deviceName: String?
            if let requestedDevice {
                deviceName = requestedDevice
            } else {
                deviceName = try await resolveDeviceName(apiKey: apiKey)
            }
            let profile = try await AirVPNAPIClient.shared.generateProfile(
                apiKey: apiKey,
                protocol: .wireguard,
                serverName: server.publicName,
                port: port,
                deviceName: deviceName
            )
            ProfileHistoryService.shared.save(
                profile: profile,
                serverName: server.publicName,
                countryCode: server.countryCode,
                vpnProtocol: .wireguard,
                port: port,
                deviceName: deviceName
            )

            let tunnel = VPNTunnelManager.shared
            // Adopt the saved tunnel first, otherwise saveTunnel would create a second profile.
            await tunnel.loadExistingManager()
            if tunnel.status == .connected || tunnel.status == .connecting {
                await tunnel.disconnect()
                await tunnel.waitUntilDisconnected()
            }
            try await tunnel.saveTunnel(
                wgQuickConfigText: profile.content,
                serverName: server.publicName,
                countryCode: server.countryCode
            )
            try await tunnel.connect()
            await waitUntilConnected(tunnel)
        } catch let error as ShortcutConnectError {
            throw error
        } catch let error as AppError {
            throw ShortcutConnectError.failed(error.errorDescription ?? error.localizedDescription)
        } catch {
            throw ShortcutConnectError.failed(error.localizedDescription)
        }
    }

    static func disconnect() async {
        let tunnel = VPNTunnelManager.shared
        await tunnel.loadExistingManager()
        await tunnel.disconnect()
        await tunnel.waitUntilDisconnected()
    }

    /// Same rule as quick connect: reuse the last used device, only ask the API for the
    /// first one when none was ever remembered.
    private static func resolveDeviceName(apiKey: String) async throws -> String? {
        if let remembered = UserDefaults.standard.string(forKey: "lastUsedDeviceName") {
            return remembered
        }
        let devices = try await AirVPNAPIClient.shared.getDevices(apiKey: apiKey).devices
        return devices.first?.name
    }

    private static func waitUntilConnected(_ tunnel: VPNTunnelManager, timeout: TimeInterval = 10) async {
        let deadline = Date().addingTimeInterval(timeout)
        while tunnel.status != .connected, Date() < deadline {
            try? await Task.sleep(for: .milliseconds(300))
        }
    }
}

// MARK: - Port choices

struct WireGuardPortOptionsProvider: DynamicOptionsProvider {
    func results() async throws -> [Int] { VPNProtocol.wireguard.ports }
}

// MARK: - Connect (choose the server each time)

struct ConnectToServerIntent: AppIntent {
    static let title: LocalizedStringResource = "Connect to Server"
    static let description = IntentDescription("Connect the VPN to an AirVPN server. You choose the server each time you run it.")
    static let openAppWhenRun: Bool = false
    static let authenticationPolicy: IntentAuthenticationPolicy = .requiresLocalDeviceAuthentication

    @Parameter(title: "Server", requestValueDialog: "Which server?")
    var server: ServerEntity

    @Parameter(title: "Device")
    var device: DeviceEntity?

    @Parameter(title: "Port", optionsProvider: WireGuardPortOptionsProvider())
    var port: Int?

    @MainActor
    func perform() async throws -> some ProvidesDialog {
        try await ShortcutConnector.connect(serverName: server.id, deviceName: device?.id, port: port)
        return .result(dialog: "Connected to \(server.id)")
    }
}

// MARK: - Connect (server configured once)

struct ConnectToSavedServerIntent: AppIntent {
    static let title: LocalizedStringResource = "Connect to Saved Server"
    static let description = IntentDescription("Connect the VPN to the server you picked in this shortcut. Choose it once in the Shortcuts app, then it always connects to the same one.")
    static let openAppWhenRun: Bool = false
    static let authenticationPolicy: IntentAuthenticationPolicy = .requiresLocalDeviceAuthentication

    static var parameterSummary: some ParameterSummary {
        Summary("Connect to \(\.$server)") {
            \.$device
            \.$port
        }
    }

    @Parameter(title: "Server")
    var server: ServerEntity?

    @Parameter(title: "Device")
    var device: DeviceEntity?

    @Parameter(title: "Port", optionsProvider: WireGuardPortOptionsProvider())
    var port: Int?

    @MainActor
    func perform() async throws -> some ProvidesDialog {
        guard let server else { throw ShortcutConnectError.noServerChosen }
        try await ShortcutConnector.connect(serverName: server.id, deviceName: device?.id, port: port)
        return .result(dialog: "Connected to \(server.id)")
    }
}

// MARK: - Disconnect

struct DisconnectVPNIntent: AppIntent {
    static let title: LocalizedStringResource = "Disconnect VPN"
    static let description = IntentDescription("Disconnect the AirDash VPN tunnel.")
    static let openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some ProvidesDialog {
        await ShortcutConnector.disconnect()
        return .result(dialog: "VPN disconnected")
    }
}
#endif
