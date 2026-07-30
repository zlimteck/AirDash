import SwiftUI

struct SessionRowView: View {
    let session: AirVPNSession
    let onDisconnect: () async -> Void
    @State private var isDisconnecting = false
    @State private var showConfirmation = false

    var durationText: String {
        guard let unix = session.connectedSinceUnix else { return "" }
        let interval = Date().timeIntervalSince1970 - Double(unix)
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.day, .hour, .minute]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: interval) ?? ""
    }

    var speedText: String {
        let down = formatBytes(session.speedRead)
        let up = formatBytes(session.speedWrite)
        return "↓ \(down) ↑ \(up)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            if let code = session.serverCountryCode {
                                FlagBadge(countryCode: code, size: 24)
                            }
                            Text(session.serverName ?? "Unknown")
                                .font(.headline)
                        }
                        if let location = session.serverLocation {
                            Text(location)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        if let device = session.deviceName {
                            Text(device)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if !durationText.isEmpty {
                            Text(durationText)
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Divider()

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("session.vpn_ip")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(session.vpnIP ?? "-")
                            .font(.caption.monospaced())
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text("session.speed")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(speedText)
                            .font(.caption.monospacedDigit())
                    }
                }

                Button {
                    showConfirmation = true
                } label: {
                    if isDisconnecting {
                        ProgressView()
                            .tint(.white)
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("session.disconnect")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .tint(.red)
                .disabled(isDisconnecting)
                .confirmationDialog("session.disconnect.confirm.title", isPresented: $showConfirmation, titleVisibility: .visible) {
                    Button("session.disconnect", role: .destructive) {
                        Task {
                            isDisconnecting = true
                            await onDisconnect()
                            isDisconnecting = false
                        }
                    }
                    Button("cancel", role: .cancel) {}
                } message: {
                    Text(String(format: NSLocalizedString("session.disconnect.confirm.message %@", comment: ""), session.serverName ?? ""))
                }
        }
    }

    private func formatBytes(_ bytes: Int?) -> String {
        guard let b = bytes else { return "0 B/s" }
        if b < 1024 { return "\(b) B/s" }
        if b < 1_048_576 { return String(format: "%.1f KB/s", Double(b) / 1024) }
        return String(format: "%.1f MB/s", Double(b) / 1_048_576)
    }
}
