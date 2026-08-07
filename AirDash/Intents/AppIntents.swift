import AppIntents

// MARK: - Server Entity

struct ServerEntity: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Server")
    static let defaultQuery = ServerEntityQuery()

    var id: String
    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(id)") }
}

struct ServerEntityQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [ServerEntity] {
        let names = SharedDataService.readServerNames()
        return identifiers.filter { names.contains($0) }.map { ServerEntity(id: $0) }
    }

    func suggestedEntities() async throws -> [ServerEntity] {
        SharedDataService.readServerNames().sorted().map { ServerEntity(id: $0) }
    }
}

// MARK: - Open Server

struct OpenServerIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Server"
    static let description = IntentDescription("Open AirDash directly on a specific server.")
    static let openAppWhenRun: Bool = true

    @Parameter(title: "Server")
    var server: ServerEntity

    func perform() async throws -> some IntentResult {
        UserDefaults.standard.set(server.id, forKey: "pendingOpenServer")
        NotificationCenter.default.post(name: .openServer, object: server.id)
        return .result()
    }
}

// MARK: - VPN Status

struct VPNStatusIntent: AppIntent {
    static let title: LocalizedStringResource = "VPN Status"
    static let description = IntentDescription("Get your current AirVPN connection status.")
    static let openAppWhenRun: Bool = false

    func perform() async throws -> some ProvidesDialog & ReturnsValue<String> {
        guard let data = SharedDataService.read() else {
            return .result(value: "Unknown", dialog: "Unable to read VPN status. Open AirDash first.")
        }
        let response: String
        if data.isVPNActive, let session = data.sessions.first {
            let server = session.serverName ?? "unknown server"
            response = "Connected to \(server)"
        } else {
            response = "Not connected"
        }
        return .result(value: response, dialog: IntentDialog(stringLiteral: response))
    }
}

// MARK: - My IP

struct MyIPIntent: AppIntent {
    static let title: LocalizedStringResource = "My IP Address"
    static let description = IntentDescription("Get your current public IP address.")
    static let openAppWhenRun: Bool = false

    func perform() async throws -> some ProvidesDialog & ReturnsValue<String> {
        guard let data = SharedDataService.read(), let ip = data.currentIP else {
            return .result(value: "Unknown", dialog: "No IP address available. Open AirDash first.")
        }
        return .result(value: ip, dialog: IntentDialog(stringLiteral: ip))
    }
}

// MARK: - Best Server

struct BestServerIntent: AppIntent {
    static let title: LocalizedStringResource = "Best Server"
    static let description = IntentDescription("Get AirDash's currently recommended server, based on load and latency.")
    static let openAppWhenRun: Bool = false

    func perform() async throws -> some ProvidesDialog & ReturnsValue<String> {
        guard let server = SharedDataService.readBestServer() else {
            return .result(value: "Unknown", dialog: "No best server available yet. Open AirDash first.")
        }
        var response = "\(server.name), \(server.location), \(server.load)% load"
        if let latency = server.latencyMs {
            response += ", \(latency) ms"
        }
        return .result(value: response, dialog: IntentDialog(stringLiteral: response))
    }
}

// MARK: - Generate Profile

enum GenerateProtocolOption: String, AppEnum {
    case wireguard, openvpn

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "VPN Protocol")
    static let caseDisplayRepresentations: [GenerateProtocolOption: DisplayRepresentation] = [
        .wireguard: "WireGuard",
        .openvpn: "OpenVPN"
    ]
}

struct DeviceEntity: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Device")
    static let defaultQuery = DeviceEntityQuery()

    var id: String
    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(id)") }
}

struct DeviceEntityQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [DeviceEntity] {
        let names = SharedDataService.readDeviceNames()
        return identifiers.filter { names.contains($0) }.map { DeviceEntity(id: $0) }
    }

    func suggestedEntities() async throws -> [DeviceEntity] {
        SharedDataService.readDeviceNames().sorted().map { DeviceEntity(id: $0) }
    }
}

struct GenerateProfileIntent: AppIntent {
    static let title: LocalizedStringResource = "Generate Profile"
    static let description = IntentDescription("Open AirDash and generate a VPN profile for a server. Importing it still requires a tap, since only the system can present that menu.")
    static let openAppWhenRun: Bool = true

    @Parameter(title: "Server")
    var server: ServerEntity

    @Parameter(title: "Protocol", default: .wireguard)
    var vpnProtocol: GenerateProtocolOption

    @Parameter(title: "Device")
    var device: DeviceEntity?

    func perform() async throws -> some IntentResult {
        UserDefaults.standard.set(server.id, forKey: "pendingOpenServer")
        UserDefaults.standard.set(vpnProtocol.rawValue, forKey: "pendingGenerateProtocol")
        if let device {
            UserDefaults.standard.set(device.id, forKey: "pendingGenerateDeviceName")
        }
        NotificationCenter.default.post(name: .openServer, object: server.id)
        return .result()
    }
}

// MARK: - Recent Profiles

struct ProfileEntity: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "VPN Profile")
    static let defaultQuery = ProfileEntityQuery()

    var id: String
    var serverName: String
    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(serverName)") }
}

struct ProfileEntityQuery: EntityQuery {
    @MainActor
    func entities(for identifiers: [String]) async throws -> [ProfileEntity] {
        ProfileHistoryService.shared.entries
            .filter { identifiers.contains($0.id.uuidString) && $0.vpnProtocol == VPNProtocol.wireguard.rawValue }
            .map { ProfileEntity(id: $0.id.uuidString, serverName: $0.serverName) }
    }

    @MainActor
    func suggestedEntities() async throws -> [ProfileEntity] {
        ProfileHistoryService.shared.entries
            .filter { $0.vpnProtocol == VPNProtocol.wireguard.rawValue }
            .map { ProfileEntity(id: $0.id.uuidString, serverName: $0.serverName) }
    }
}

struct ShowRecentProfilesIntent: AppIntent {
    static let title: LocalizedStringResource = "Recent Profiles"
    static let description = IntentDescription("Open AirDash's list of recently generated VPN profiles.")
    static let openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        UserDefaults.standard.set(true, forKey: "pendingShowProfiles")
        NotificationCenter.default.post(name: .shortcutAction, object: 1)
        NotificationCenter.default.post(name: .showRecentProfiles, object: nil)
        return .result()
    }
}

// MARK: - Show Profile QR Code

struct ShowProfileQRCodeIntent: AppIntent {
    static let title: LocalizedStringResource = "Show Profile QR Code"
    static let description = IntentDescription("Open AirDash and show the QR code for a previously generated WireGuard profile.")
    static let openAppWhenRun: Bool = true

    @Parameter(title: "Profile")
    var profile: ProfileEntity

    func perform() async throws -> some IntentResult {
        UserDefaults.standard.set(profile.id, forKey: "pendingQRProfileId")
        UserDefaults.standard.set(true, forKey: "pendingShowProfiles")
        NotificationCenter.default.post(name: .shortcutAction, object: 1)
        NotificationCenter.default.post(name: .showRecentProfiles, object: nil)
        return .result()
    }
}

// MARK: - Shortcuts Provider

struct AirDashShortcuts: AppShortcutsProvider {
    @AppShortcutsBuilder
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: VPNStatusIntent(),
            phrases: [
                "Check VPN status in \(.applicationName)",
                "VPN status with \(.applicationName)",
                "Am I connected in \(.applicationName)"
            ],
            shortTitle: "VPN Status",
            systemImageName: "lock.shield"
        )
        AppShortcut(
            intent: MyIPIntent(),
            phrases: [
                "My IP address in \(.applicationName)",
                "What's my IP in \(.applicationName)"
            ],
            shortTitle: "My IP Address",
            systemImageName: "network"
        )
        AppShortcut(
            intent: OpenServerIntent(),
            phrases: [
                "Open \(\.$server) in \(.applicationName)",
                "Connect to \(\.$server) with \(.applicationName)"
            ],
            shortTitle: "Open Server",
            systemImageName: "server.rack"
        )
        AppShortcut(
            intent: BestServerIntent(),
            phrases: [
                "Best server in \(.applicationName)",
                "What's the best server in \(.applicationName)"
            ],
            shortTitle: "Best Server",
            systemImageName: "star.fill"
        )
        AppShortcut(
            intent: GenerateProfileIntent(),
            phrases: [
                "Generate a profile for \(\.$server) in \(.applicationName)",
                "Create a VPN profile for \(\.$server) with \(.applicationName)"
            ],
            shortTitle: "Generate Profile",
            systemImageName: "doc.badge.plus"
        )
        AppShortcut(
            intent: ShowRecentProfilesIntent(),
            phrases: [
                "Recent profiles in \(.applicationName)",
                "Show my VPN profiles in \(.applicationName)"
            ],
            shortTitle: "Recent Profiles",
            systemImageName: "doc.badge.clock"
        )
        AppShortcut(
            intent: ShowProfileQRCodeIntent(),
            phrases: [
                "Show QR code for \(\.$profile) in \(.applicationName)",
                "QR code for \(\.$profile) with \(.applicationName)"
            ],
            shortTitle: "Profile QR Code",
            systemImageName: "qrcode"
        )
    }
}
