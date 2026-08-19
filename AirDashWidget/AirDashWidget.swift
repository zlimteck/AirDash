import AppIntents
import SwiftUI
import WidgetKit
import FlagKit

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
        let connectedSinceUnix: Int?
        let isThisDevice: Bool
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
            sessions: [WidgetData.WidgetSession(deviceName: "iPhone", serverName: "Menkab", serverCountryCode: "SE", connectedSinceUnix: Int(Date().timeIntervalSince1970) - 3600, isThisDevice: true)],
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
struct AirDashWidgetBundle: WidgetBundle {
    var body: some Widget {
        AirDashWidget()
        AirDashStatusWidget()
    }
}

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

// MARK: - Status widget (VPN status + account info only)

struct AirDashStatusEntry: TimelineEntry {
    let date: Date
    let data: WidgetData?
}

struct AirDashStatusProvider: TimelineProvider {
    private let suiteName = "group.com.airdash.ios"

    func placeholder(in context: Context) -> AirDashStatusEntry {
        AirDashStatusEntry(date: .now, data: WidgetData(
            currentIP: "89.38.xxx.xxx",
            isVPNActive: true,
            sessions: [WidgetData.WidgetSession(deviceName: "iPhone", serverName: "Menkab", serverCountryCode: "SE", connectedSinceUnix: Int(Date().timeIntervalSince1970) - 3600, isThisDevice: true)],
            expirationDays: 180,
            login: "user",
            updatedAt: .now
        ))
    }

    func getSnapshot(in context: Context, completion: @escaping (AirDashStatusEntry) -> Void) {
        completion(AirDashStatusEntry(date: .now, data: loadWidgetData()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<AirDashStatusEntry>) -> Void) {
        let entry = AirDashStatusEntry(date: .now, data: loadWidgetData())
        let next = Calendar.current.date(byAdding: .minute, value: 15, to: .now)!
        completion(Timeline(entries: [entry], policy: .after(next)))
    }

    private func loadWidgetData() -> WidgetData? {
        guard let defaults = UserDefaults(suiteName: suiteName),
              let data = defaults.data(forKey: "widgetData"),
              let decoded = try? JSONDecoder().decode(WidgetData.self, from: data)
        else { return nil }
        return decoded
    }
}

struct AirDashStatusWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "AirDashStatusWidget", provider: AirDashStatusProvider()) { entry in
            AirDashStatusWidgetView(data: entry.data)
        }
        .configurationDisplayName("AirDash Compte")
        .description("Statut VPN et informations de compte.")
        .supportedFamilies([.systemSmall])
    }
}

struct AirDashStatusWidgetView: View {
    let data: WidgetData?
    var isVPN: Bool { data?.isVPNActive ?? false }
    var mySession: WidgetData.WidgetSession? {
        data?.sessions.first(where: \.isThisDevice) ?? data?.sessions.first
    }

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
            Spacer(minLength: 8)
            Image(systemName: isVPN ? "shield.fill" : "shield.slash")
                .font(.title2)
                .foregroundStyle(isVPN ? .green : .secondary)
                .frame(maxWidth: .infinity)
            Text(isVPN ? "VPN actif" : "VPN inactif")
                .font(.caption.bold())
                .foregroundStyle(isVPN ? .green : .secondary)
                .frame(maxWidth: .infinity)
                .padding(.top, 2)
            if isVPN, let session = mySession {
                HStack(spacing: 4) {
                    WidgetFlagBadge(countryCode: session.serverCountryCode, size: 12)
                    Text(session.serverName ?? "—")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 3)
            }
            Spacer(minLength: 8)
            VStack(alignment: .leading, spacing: 1) {
                if let login = data?.login {
                    Text(login)
                        .font(.caption2.bold())
                        .lineLimit(1)
                }
                if let days = data?.expirationDays {
                    Text("Expire dans \(days) j")
                        .font(.caption2)
                        .foregroundStyle(days < 30 ? .orange : .secondary)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .containerBackground(for: .widget) {
            Color(.systemBackground)
        }
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
            default:            SmallWidgetView(data: entry.data, watchedServer: entry.watchedServer)
            }
        }
        .containerBackground(for: .widget) {
            Color(.systemBackground)
        }
    }
}

private func loadColor(_ load: Int) -> Color {
    switch load {
    case ..<50: .green
    case 50..<80: .orange
    default: .red
    }
}

// MARK: - Small widget

struct SmallWidgetView: View {
    let data: WidgetData?
    let watchedServer: WidgetServerData?
    var isVPN: Bool { data?.isVPNActive ?? false }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let server = watchedServer {
                HStack {
                    Text("AirDash")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    Spacer()
                    Circle()
                        .fill(isVPN ? Color.green : Color.secondary.opacity(0.4))
                        .frame(width: 8, height: 8)
                }
                Spacer(minLength: 8)
                HStack(spacing: 4) {
                    WidgetFlagBadge(countryCode: server.countryCode, size: 14)
                    Text(server.name)
                        .font(.system(size: 11, weight: .semibold))
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                HStack {
                    Text("charge")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(server.load)%")
                        .font(.caption.weight(.semibold).monospacedDigit())
                        .foregroundStyle(loadColor(server.load))
                }
                LoadBarView(load: server.load)
                    .padding(.top, 2)
                Spacer(minLength: 10)
            } else {
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
                    .frame(maxWidth: .infinity)
                Text(isVPN ? "VPN actif" : "VPN inactif")
                    .font(.caption.bold())
                    .foregroundStyle(isVPN ? .green : .secondary)
                    .frame(maxWidth: .infinity)
                Spacer()
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(data?.currentIP ?? "—")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                if let ms = watchedServer?.latencyMs {
                    Text("\(ms) ms")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(latencyColor(ms))
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private func latencyColor(_ ms: Int) -> Color {
        switch ms {
        case ..<50: .green
        case 50..<150: .orange
        default: .red
        }
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
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        WidgetFlagBadge(countryCode: server.countryCode, size: 18)
                        Text(server.name)
                            .font(.caption.bold())
                            .lineLimit(1)
                        Image(systemName: "star.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(.yellow)
                        Spacer()
                        Circle()
                            .fill(server.isHealthy ? Color.green : Color.red)
                            .frame(width: 6, height: 6)
                    }
                    HStack(spacing: 8) {
                        Text("\(server.load)%")
                            .font(.caption2.weight(.semibold).monospacedDigit())
                            .foregroundStyle(loadColor(server.load))
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
                    LoadBarView(load: server.load)
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

    private var durationText: String? {
        guard let unix = session.connectedSinceUnix else { return nil }
        let interval = Date().timeIntervalSince1970 - Double(unix)
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.day, .hour, .minute]
        formatter.unitsStyle = .abbreviated
        formatter.maximumUnitCount = 2
        return formatter.string(from: interval)
    }

    var body: some View {
        HStack(spacing: 8) {
            WidgetFlagBadge(countryCode: session.serverCountryCode, size: 20)
            VStack(alignment: .leading, spacing: 0) {
                Text(session.deviceName ?? "—").font(.caption.bold()).lineLimit(1)
                Text(session.serverName ?? "—").font(.caption2).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 4)
            if let durationText {
                Text(durationText)
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct LoadBarView: View {
    let load: Int
    var height: CGFloat = 6

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(Color.secondary.opacity(0.2))
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(loadColor(load))
                    .frame(width: geo.size.width * min(Double(load) / 100, 1))
            }
        }
        .frame(height: height)
    }
}

private struct WidgetFlagBadge: View {
    let countryCode: String?
    var size: CGFloat = 28

    var body: some View {
        Group {
            if let countryCode, let flag = Flag(countryCode: countryCode.uppercased()) {
                Image(uiImage: flag.image(style: .roundedRect))
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Color.secondary.opacity(0.15)
            }
        }
        .frame(width: size, height: size * 0.72)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: size * 0.14, style: .continuous)
                .strokeBorder(.primary.opacity(0.1), lineWidth: 0.5)
        )
    }
}
