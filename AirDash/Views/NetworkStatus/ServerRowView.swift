import SwiftUI

struct ServerRowView: View {
    let server: AirVPNServer
    let latency: Int?
    let isMeasured: Bool
    var isFavorite: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            FlagBadge(countryCode: server.countryCode, size: 28)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(server.publicName)
                        .font(.headline)
                    HealthDot(health: server.health)
                    if isFavorite {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundStyle(.yellow)
                    }
                }
                Text(server.location)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let warning = server.warning, !warning.isEmpty {
                    Text(warning.trimmingCharacters(in: .init(charactersIn: "* ")))
                        .font(.caption2)
                        .foregroundStyle(.orange)
                } else {
                    LoadBar(load: server.currentLoad)
                        .frame(maxWidth: 120)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("\(Int(server.currentLoad))%")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(loadColor(server.currentLoad))
                Text("\(server.users) \(Text("network.users").foregroundStyle(.secondary))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                latencyView
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var latencyView: some View {
        if !isMeasured {
            ProgressView()
                .scaleEffect(0.5)
                .frame(height: 12)
        } else if let ms = latency {
            Text("\(ms) ms")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(latencyColor(ms))
        } else {
            Text("— ms")
                .font(.caption2)
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

/// Stale-while-revalidate placeholder shown instead of the Best Server card while
/// the fresh ping sweep is still running, using the value cached from the previous session.
struct CachedBestServerRow: View {
    let server: SharedServerData

    var body: some View {
        HStack(spacing: 12) {
            FlagBadge(countryCode: server.countryCode, size: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(server.name)
                    .font(.headline)
                Text(server.location)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("\(server.load)%")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
                if let ms = server.latencyMs {
                    Text("\(ms) ms")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.vertical, 4)
        .opacity(0.6)
    }
}
