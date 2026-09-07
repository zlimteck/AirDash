import ActivityKit

/// Shared between the main app (starts/updates/ends the Activity from `VPNTunnelManager`)
/// and the widget extension (renders it) — kept free of NetworkExtension so the widget
/// extension doesn't need to link it just to display the Activity.
struct VPNSessionAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var status: VPNActivityStatus
        var connectedSinceUnix: Int?
    }

    let serverName: String
    let countryCode: String?
}

enum VPNActivityStatus: String, Codable, Hashable {
    case connecting, connected, reasserting, disconnecting
}
