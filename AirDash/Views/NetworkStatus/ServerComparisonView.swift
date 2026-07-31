import SwiftUI

struct ServerComparisonView: View {
    let servers: [AirVPNServer]
    let latencies: [String: Int]
    let measuredIds: Set<String>
    let onClear: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(servers) { server in
                        NavigationLink(value: server) {
                            ServerCompareCard(
                                server: server,
                                latency: latencies[server.id],
                                isMeasured: measuredIds.contains(server.id)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("compare.title")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: AirVPNServer.self) { server in
                ServerDetailView(server: server)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        onClear()
                        dismiss()
                    } label: {
                        Text("compare.clear")
                    }
                    .foregroundStyle(.red)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("compare.close") { dismiss() }
                }
            }
        }
    }
}

private struct ServerCompareCard: View {
    let server: AirVPNServer
    let latency: Int?
    let isMeasured: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 10) {
                FlagBadge(countryCode: server.countryCode, size: 30)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 5) {
                        Text(server.publicName)
                            .font(.subheadline.bold())
                        HealthDot(health: server.health)
                    }
                    Text(server.location)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Divider()

            // Stats 2×2
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    statCell(label: "compare.load") {
                        HStack(spacing: 6) {
                            Text("\(Int(server.currentLoad))%")
                                .font(.subheadline.bold().monospacedDigit())
                                .foregroundStyle(loadColor(server.currentLoad))
                            LoadBar(load: server.currentLoad)
                                .frame(maxWidth: 52)
                        }
                    }
                    verticalDivider
                    statCell(label: "compare.users") {
                        Text("\(server.users)")
                            .font(.subheadline.bold().monospacedDigit())
                    }
                }
                .frame(height: 52)

                Divider()

                HStack(spacing: 0) {
                    statCell(label: "compare.ping") {
                        pingView
                    }
                    verticalDivider
                    statCell(label: "IPv4") {
                        Text(server.ipV4In1 ?? "—")
                            .font(.caption2.monospaced())
                            .foregroundStyle(server.ipV4In1 != nil ? .primary : .tertiary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .padding(.horizontal, 4)
                    }
                }
                .frame(height: 52)
            }

            if let ip6 = server.ipV6In1 {
                Divider()
                HStack(spacing: 6) {
                    Text("IPv6")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(ip6)
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
            }
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var verticalDivider: some View {
        Color(.separator)
            .frame(width: 0.5)
            .padding(.vertical, 10)
    }

    private func statCell<Content: View>(label: LocalizedStringKey, @ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            content()
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var pingView: some View {
        if !isMeasured {
            ProgressView().scaleEffect(0.7)
        } else if let ms = latency {
            Text("\(ms) ms")
                .font(.subheadline.bold().monospacedDigit())
                .foregroundStyle(latencyColor(ms))
        } else {
            Text("— ms")
                .font(.subheadline.bold())
                .foregroundStyle(.tertiary)
        }
    }

    private func loadColor(_ load: Double) -> Color {
        switch load {
        case ..<50: .green
        case 50..<80: .orange
        default: .red
        }
    }

    private func latencyColor(_ ms: Int) -> Color {
        switch ms {
        case ..<50: .green
        case 50..<150: .orange
        default: .red
        }
    }
}
