import ActivityKit
import SwiftUI
import WidgetKit
import FlagKit

struct AirDashVPNLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: VPNSessionAttributes.self) { context in
            VPNLiveActivityLockScreenView(attributes: context.attributes, state: context.state)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 6) {
                        VPNLiveActivityFlag(countryCode: context.attributes.countryCode, size: 22)
                        Text(context.attributes.serverName)
                            .font(.caption.bold())
                            .lineLimit(1)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VPNLiveActivityStatusBadge(status: context.state.status)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    if context.state.status == .connected, let unix = context.state.connectedSinceUnix {
                        Text(Date(timeIntervalSince1970: TimeInterval(unix)), style: .timer)
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
            } compactLeading: {
                Image(systemName: "lock.shield.fill")
                    .foregroundStyle(context.state.status == .connected ? .green : .secondary)
            } compactTrailing: {
                if context.state.status == .connected, let unix = context.state.connectedSinceUnix {
                    Text(Date(timeIntervalSince1970: TimeInterval(unix)), style: .timer)
                        .font(.caption2.monospacedDigit())
                        .frame(width: 40)
                } else {
                    VPNLiveActivityStatusBadge(status: context.state.status, compact: true)
                }
            } minimal: {
                Image(systemName: "lock.shield.fill")
                    .foregroundStyle(context.state.status == .connected ? .green : .secondary)
            }
        }
    }
}

private struct VPNLiveActivityLockScreenView: View {
    let attributes: VPNSessionAttributes
    let state: VPNSessionAttributes.ContentState

    var body: some View {
        HStack(spacing: 12) {
            VPNLiveActivityFlag(countryCode: attributes.countryCode, size: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(attributes.serverName)
                    .font(.headline)
                    .lineLimit(1)
                if state.status == .connected, let unix = state.connectedSinceUnix {
                    Text(Date(timeIntervalSince1970: TimeInterval(unix)), style: .timer)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                } else {
                    Text(state.status.label)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            VPNLiveActivityStatusBadge(status: state.status)
        }
        .padding(16)
    }
}

private struct VPNLiveActivityStatusBadge: View {
    let status: VPNActivityStatus
    var compact: Bool = false

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(status == .connected ? Color.green : Color.orange)
                .frame(width: 7, height: 7)
            if !compact {
                Text(status.label)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(status == .connected ? .green : .orange)
            }
        }
    }
}

private extension VPNActivityStatus {
    var label: String {
        switch self {
        case .connecting:    "Connexion…"
        case .connected:     "Connecté"
        case .reasserting:   "Reconnexion…"
        case .disconnecting: "Déconnexion…"
        }
    }
}

private struct VPNLiveActivityFlag: View {
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
    }
}
