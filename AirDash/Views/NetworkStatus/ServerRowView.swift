import SwiftUI

struct ServerRowView: View {
    let server: AirVPNServer

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
            }
        }
        .padding(.vertical, 4)
    }

    private func loadColor(_ load: Double) -> Color {
        switch load {
        case ..<50: .green
        case 50..<80: .orange
        default: .red
        }
    }
}
