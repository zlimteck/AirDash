import SwiftUI

struct ServerRowView: View {
    let server: AirVPNServer
    let latency: Int?
    let isMeasured: Bool

    var body: some View {
        HStack(spacing: 12) {
            FlagBadge(countryCode: server.countryCode, size: 28)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(server.publicName)
                        .font(.headline)
                    HealthDot(health: server.health)
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
