import WidgetKit
import SwiftUI

// MARK: - Shared model (mirrors SharedWidgetData in main app)

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

// MARK: - Timeline entry

struct AirDashEntry: TimelineEntry {
    let date: Date
    let data: WidgetData?
}

// MARK: - Provider

struct AirDashProvider: TimelineProvider {
    private let suiteName = "group.com.airdash.ios"
    private let key = "widgetData"

    func placeholder(in context: Context) -> AirDashEntry {
        AirDashEntry(date: .now, data: WidgetData(
            currentIP: "89.38.xxx.xxx",
            isVPNActive: true,
            sessions: [
                WidgetData.WidgetSession(deviceName: "iPhone", serverName: "Menkab", serverCountryCode: "SE")
            ],
            expirationDays: 180,
            login: "user",
            updatedAt: .now
        ))
    }

    func getSnapshot(in context: Context, completion: @escaping (AirDashEntry) -> Void) {
        completion(AirDashEntry(date: .now, data: load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<AirDashEntry>) -> Void) {
        let entry = AirDashEntry(date: .now, data: load())
        let next = Calendar.current.date(byAdding: .minute, value: 15, to: .now)!
        completion(Timeline(entries: [entry], policy: .after(next)))
    }

    private func load() -> WidgetData? {
        guard let defaults = UserDefaults(suiteName: suiteName),
              let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode(WidgetData.self, from: data)
        else { return nil }
        return decoded
    }
}

// MARK: - Widget declaration

@main
struct AirDashWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "AirDashWidget", provider: AirDashProvider()) { entry in
            AirDashWidgetView(entry: entry)
        }
        .configurationDisplayName("AirDash")
        .description("Statut VPN et sessions actives")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Root view

struct AirDashWidgetView: View {
    let entry: AirDashEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        Group {
            if family == .systemMedium {
                MediumWidgetView(data: entry.data)
            } else {
                SmallWidgetView(data: entry.data)
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

            if let count = data?.sessions.count, count > 0 {
                Text("\(count) session\(count > 1 ? "s" : "")")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                Text("Aucune session")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
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

            Divider().padding(.vertical, 8)

            // Sessions
            if let sessions = data?.sessions, !sessions.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(sessions.prefix(3).enumerated()), id: \.offset) { _, session in
                        HStack(spacing: 8) {
                            Text(flagEmoji(session.serverCountryCode))
                                .font(.body)
                            VStack(alignment: .leading, spacing: 0) {
                                Text(session.deviceName ?? "—")
                                    .font(.caption.bold())
                                    .lineLimit(1)
                                Text(session.serverName ?? "—")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                }
            } else {
                HStack {
                    Image(systemName: "shield.slash")
                        .foregroundStyle(.secondary)
                    Text("Aucune session active")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxHeight: .infinity)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private func flagEmoji(_ code: String?) -> String {
        guard let code else { return "🏳️" }
        let base: UInt32 = 127397
        return code.uppercased().unicodeScalars.compactMap {
            Unicode.Scalar($0.value + base).map(String.init)
        }.joined()
    }
}
