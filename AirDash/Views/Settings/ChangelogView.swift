import SwiftUI

private struct ChangelogEntry {
    let version: String
    let changes: [String]
}

private let changelog: [ChangelogEntry] = [
    ChangelogEntry(version: "1.0.5", changes: [
        "changelog.1_0_5.multi_account",
        "changelog.1_0_5.devices",
        "changelog.1_0_5.dns_lists",
        "changelog.1_0_5.launch_screen"
    ]),
    ChangelogEntry(version: "1.0.4", changes: [
        "changelog.1_0_4.biometric_lock",
        "changelog.1_0_4.icon_picker",
        "changelog.1_0_4.comparison",
        "changelog.1_0_4.profile_history",
        "changelog.1_0_4.qr_code",
        "changelog.1_0_4.swipe_disconnect",
        "changelog.1_0_4.post_generation"
    ]),
    ChangelogEntry(version: "1.0.3", changes: [
        "changelog.1_0_3.widget",
        "changelog.1_0_3.server_detail",
        "changelog.1_0_3.ip_addresses",
        "changelog.1_0_3.dashboard",
        "changelog.1_0_3.network",
        "changelog.1_0_3.auto_refresh",
        "changelog.1_0_3.renewal",
        "changelog.1_0_3.vpn_import"
    ]),
    ChangelogEntry(version: "1.0.2", changes: [
        "changelog.1_0_2.notifications",
        "changelog.1_0_2.shortcuts",
        "changelog.1_0_2.changelog",
        "changelog.1_0_2.ipv6",
        "changelog.1_0_2.ping_fallback",
        "changelog.1_0_2.credits"
    ]),
    ChangelogEntry(version: "1.0.1", changes: [
        "changelog.1_0_1.quick_actions",
        "changelog.1_0_1.ping",
        "changelog.1_0_1.sort_ping",
        "changelog.1_0_1.sort_persistent",
        "changelog.1_0_1.favorites"
    ]),
    ChangelogEntry(version: "1.0.0", changes: [
        "changelog.1_0_0.initial"
    ])
]

struct ChangelogView: View {
    var body: some View {
        List {
            ForEach(changelog, id: \.version) { entry in
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(entry.changes, id: \.self) { change in
                            HStack(alignment: .top, spacing: 8) {
                                Text("·")
                                    .foregroundStyle(.secondary)
                                Text(LocalizedStringKey(change))
                                    .font(.subheadline)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("v\(entry.version)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .textCase(nil)
                }
            }
        }
        .navigationTitle("settings.changelog")
        .navigationBarTitleDisplayMode(.large)
    }
}
