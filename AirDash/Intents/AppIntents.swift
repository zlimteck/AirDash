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
    }
}
