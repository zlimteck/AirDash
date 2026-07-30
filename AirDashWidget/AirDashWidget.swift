import AppIntents
import SwiftUI
import WidgetKit

// MARK: - Shared models (mirror main app structs)

struct WidgetData: Codable {
    let currentIP: String?
    let isVPNActive: Bool
    let sessions: [WidgetSession]
    let expirationDays: Int?
    let login: String?
    let updatedAt: Date

    struct WidgetSession: Codable {
        let deviceName: String?
        let serverName: String?
        let serverCountryCode: String?
    }
}

struct WidgetServerData: Codable {
    let id: String
    let name: String
    let countryCode: String
    let load: Int
    let users: Int
    let isHealthy: Bool
    let latencyMs: Int?
}

// MARK: - AppEntity for server picker

struct ServerAppEntity: AppEntity {
    let id: String
    let name: String
    let countryCode: String

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Serveur"
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
    static let defaultQuery = ServerEntityQuery()
}

struct ServerEntityQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [ServerAppEntity] {
        loadAll().filter { identifiers.contains($0.id) }
    }
    func suggestedEntities() async throws -> [ServerAppEntity] {
        loadAll()
    }
    private func loadAll() -> [ServerAppEntity] {
        guard let defaults = UserDefaults(suiteName: "group.com.airdash.ios"),
              let data = defaults.data(forKey: "favoriteServersData"),
              let servers = try? JSONDecoder().decode([WidgetServerData].self, from: data)
        else { return [] }
        return servers.map { ServerAppEntity(id: $0.id, name: $0.name, countryCode: $0.countryCode) }
    }
}

// MARK: - Widget configuration intent

struct SelectServerIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Configuration AirDash"
    static let description = IntentDescription("Choisissez un serveur favori à surveiller.")

    @Parameter(title: "Serveur favori")
    var server: ServerAppEntity?
}

// MARK: - Timeline entry

struct AirDashEntry: TimelineEntry {
    let date: Date
    let data: WidgetData?
    let watchedServer: WidgetServerData?
}

// MARK: - Provider

struct AirDashProvider: AppIntentTimelineProvider {
    private let suiteName = "group.com.airdash.ios"

    func placeholder(in context: Context) -> AirDashEntry {
        AirDashEntry(date: .now, data: WidgetData(
            currentIP: "89.38.xxx.xxx",
            isVPNActive: true,
            sessions: [WidgetData.WidgetSession(deviceName: "iPhone", serverName: "Menkab", serverCountryCode: "SE")],
            expirationDays: 180,
            login: "user",
            updatedAt: .now
        ), watchedServer: nil)
    }

    func snapshot(for configuration: SelectServerIntent, in context: Context) async -> AirDashEntry {
        AirDashEntry(date: .now, data: loadWidgetData(), watchedServer: loadWatchedServer(configuration))
    }

    func timeline(for configuration: SelectServerIntent, in context: Context) async -> Timeline<AirDashEntry> {
        let entry = AirDashEntry(date: .now, data: loadWidgetData(), watchedServer: loadWatchedServer(configuration))
        let next = Calendar.current.date(byAdding: .minute, value: 15, to: .now)!
        return Timeline(entries: [entry], policy: .after(next))
    }

    private func loadWidgetData() -> WidgetData? {
        guard let defaults = UserDefaults(suiteName: suiteName),
              let data = defaults.data(forKey: "widgetData"),
              let decoded = try? JSONDecoder().decode(WidgetData.self, from: data)
        else { return nil }
        return decoded
    }

    private func loadWatchedServer(_ config: SelectServerIntent) -> WidgetServerData? {
        guard let defaults = UserDefaults(suiteName: suiteName),
              let data = defaults.data(forKey: "favoriteServersData"),
              let servers = try? JSONDecoder().decode([WidgetServerData].self, from: data),
              !servers.isEmpty
        else { return nil }
        // If a server is explicitly selected, show it; otherwise show first favorite
        if let serverID = config.server?.id,
           let match = servers.first(where: { $0.id == serverID }) {
            return match
        }
        return servers.first
    }
}

// MARK: - Widget declaration

@main
struct AirDashWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "AirDashWidget", intent: SelectServerIntent.self, provider: AirDashProvider()) { entry in
            AirDashWidgetView(entry: entry)
        }
        .configurationDisplayName("AirDash")
        .description("Statut VPN, sessions actives et serveur favori.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Root view

struct AirDashWidgetView: View {
    let entry: AirDashEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        Group {
            switch family {
            case .systemLarge:  LargeWidgetView(data: entry.data, watchedServer: entry.watchedServer)
            case .systemMedium: MediumWidgetView(data: entry.data)
            default:            SmallWidgetView(data: entry.data)
            }
        }
        .containerBackground(for: .widget) {
            Color(.systemBackground)
        }
    }
}

// MARK: - Small widget

struct SmallWidgetView: View {
    let data: WidgetData?
    var isVPN: Bool { data?.isVPNActive ?? false }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("AirDash")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                Spacer()
                Circle()
                    .fill(isVPN ? Color.green : Color.secondary.opacity(0.4))
                    .frame(width: 8, height: 8)
            }
            Spacer()
            Image(systemName: isVPN ? "shield.fill" : "shield.slash")
                .font(.title2)
                .foregroundStyle(isVPN ? .green : .secondary)
            Text(isVPN ? "VPN actif" : "VPN inactif")
                .font(.caption.bold())
                .foregroundStyle(isVPN ? .green : .secondary)
                .padding(.top, 2)
            Text(data?.currentIP ?? "—")
                .font(.caption2.monospaced())
                .foregroundStyle(.primary)
                .padding(.top, 1)
            Spacer()
            let count = data?.sessions.count ?? 0
            Text(count > 0 ? "\(count) session\(count > 1 ? "s" : "")" : "Aucune session")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

// MARK: - Medium widget

struct MediumWidgetView: View {
    let data: WidgetData?
    var isVPN: Bool { data?.isVPNActive ?? false }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("AirDash")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    Text(data?.currentIP ?? "—")
                        .font(.subheadline.monospaced())
                        .foregroundStyle(.primary)
                }
                Spacer()
                HStack(spacing: 6) {
                    Circle()
                        .fill(isVPN ? Color.green : Color.secondary.opacity(0.4))
                        .frame(width: 8, height: 8)
                    Text(isVPN ? "VPN actif" : "Inactif")
                        .font(.caption.bold())
                        .foregroundStyle(isVPN ? .green : .secondary)
                }
            }
            Divider().padding(.vertical, 8)
            if let sessions = data?.sessions, !sessions.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(sessions.prefix(3).enumerated()), id: \.offset) { _, session in
                        SessionRowWidget(session: session)
                    }
                }
            } else {
                noSessionView
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

// MARK: - Large widget

struct LargeWidgetView: View {
    let data: WidgetData?
    let watchedServer: WidgetServerData?
    var isVPN: Bool { data?.isVPNActive ?? false }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("AirDash")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    Text(data?.currentIP ?? "—")
                        .font(.subheadline.monospaced())
                        .foregroundStyle(.primary)
                }
                Spacer()
                HStack(spacing: 6) {
                    Circle()
                        .fill(isVPN ? Color.green : Color.secondary.opacity(0.4))
                        .frame(width: 8, height: 8)
                    Text(isVPN ? "VPN actif" : "Inactif")
                        .font(.caption.bold())
                        .foregroundStyle(isVPN ? .green : .secondary)
                }
            }

            // Watched server
            if let server = watchedServer {
                Divider().padding(.vertical, 8)
                HStack(spacing: 10) {
                    Text(flagEmoji(server.countryCode))
                        .font(.title3)
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(server.name)
                                .font(.caption.bold())
                                .lineLimit(1)
                            Spacer()
                            Circle()
                                .fill(server.isHealthy ? Color.green : Color.red)
                                .frame(width: 6, height: 6)
                        }
                        HStack(spacing: 8) {
                            Text("\(server.load)%")
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(server.load > 70 ? .red : server.load > 40 ? .orange : .green)
                            Text("·")
                                .foregroundStyle(.secondary)
                            Text("\(server.users) users")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            if let ms = server.latencyMs {
                                Text("·")
                                    .foregroundStyle(.secondary)
                                Text("\(ms) ms")
                                    .font(.caption2.monospacedDigit())
                                    .foregroundStyle(ms < 50 ? .green : ms < 150 ? .orange : .red)
                            }
                        }
                    }
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.secondary.opacity(0.08)))
            }

            Divider().padding(.vertical, 8)

            // Sessions
            if let sessions = data?.sessions, !sessions.isEmpty {
                Text("Sessions actives (\(sessions.count))")
                    .font(.caption2.bold())
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 6)
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(sessions.prefix(6).enumerated()), id: \.offset) { _, session in
                        SessionRowWidget(session: session)
                    }
                }
            } else {
                noSessionView
            }

            Spacer(minLength: 0)

            // Footer: expiration
            if let days = data?.expirationDays {
                Divider().padding(.vertical, 6)
                Label("Expire dans \(days) j", systemImage: "calendar")
                    .font(.caption2)
                    .foregroundStyle(days < 30 ? .orange : .secondary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

// MARK: - Shared subviews

private var noSessionView: some View {
    HStack {
        Image(systemName: "shield.slash").foregroundStyle(.secondary)
        Text("Aucune session active").font(.caption).foregroundStyle(.secondary)
    }
    .frame(maxHeight: .infinity)
}

struct SessionRowWidget: View {
    let session: WidgetData.WidgetSession
    var body: some View {
        HStack(spacing: 8) {
            Text(flagEmoji(session.serverCountryCode)).font(.body)
            VStack(alignment: .leading, spacing: 0) {
                Text(session.deviceName ?? "—").font(.caption.bold()).lineLimit(1)
                Text(session.serverName ?? "—").font(.caption2).foregroundStyle(.secondary).lineLimit(1)
            }
        }
    }
}

private func flagEmoji(_ code: String?) -> String {
    guard let code else { return "🏳️" }
    let base: UInt32 = 127397
    return code.uppercased().unicodeScalars.compactMap {
        Unicode.Scalar($0.value + base).map(String.init)
    }.joined()
}
