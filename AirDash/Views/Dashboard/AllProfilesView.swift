import SwiftUI

enum ProfileProtocolFilter: String, CaseIterable {
    case all, wireguard, openvpn

    var label: LocalizedStringKey {
        switch self {
        case .all:       "profiles.filter.all"
        case .wireguard: "profiles.filter.wireguard"
        case .openvpn:   "profiles.filter.openvpn"
        }
    }
}

struct AllProfilesView: View {
    @State private var entries: [ProfileHistoryEntry] = ProfileHistoryService.shared.entries
    @State private var searchText = ""
    @State private var protocolFilter: ProfileProtocolFilter = .all
    @State private var showQRCode = false
    @State private var qrContent = ""
    @State private var entryPendingDeletion: ProfileHistoryEntry? = nil
    @State private var showClearAllConfirm = false

    private var filteredEntries: [ProfileHistoryEntry] {
        var result = entries.sorted { $0.date > $1.date }
        if protocolFilter != .all {
            result = result.filter { $0.vpnProtocol == protocolFilter.rawValue }
        }
        guard !searchText.isEmpty else { return result }
        return result.filter {
            $0.serverName.localizedCaseInsensitiveContains(searchText) ||
            (VPNProtocol(rawValue: $0.vpnProtocol)?.displayName ?? $0.vpnProtocol).localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        List {
            if filteredEntries.isEmpty {
                ContentUnavailableView("profiles.empty", systemImage: "doc.badge.clock")
                    .listRowSeparator(.hidden)
            } else {
                Section {
                    ForEach(filteredEntries) { entry in
                        ProfileHistoryRow(entry: entry)
                            .contextMenu {
                                if VPNProtocol(rawValue: entry.vpnProtocol) == .wireguard {
                                    Button {
                                        qrContent = entry.content
                                        showQRCode = true
                                    } label: {
                                        Label("profiles.qr_code", systemImage: "qrcode")
                                    }
                                }
                                Button {
                                    reimport(entry)
                                } label: {
                                    Label("profiles.import", systemImage: "square.and.arrow.down")
                                }
                                Button(role: .destructive) {
                                    entryPendingDeletion = entry
                                } label: {
                                    Label("delete", systemImage: "trash")
                                }
                            }
                        .swipeActions(edge: .leading, allowsFullSwipe: false) {
                            if VPNProtocol(rawValue: entry.vpnProtocol) == .wireguard {
                                Button {
                                    qrContent = entry.content
                                    showQRCode = true
                                } label: {
                                    Label("profiles.qr_code", systemImage: "qrcode")
                                }
                                .tint(.indigo)
                            }
                            Button {
                                reimport(entry)
                            } label: {
                                Label("profiles.import", systemImage: "square.and.arrow.down")
                            }
                            .tint(.blue)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                entryPendingDeletion = entry
                            } label: {
                                Label("delete", systemImage: "trash")
                            }
                        }
                    }
                } footer: {
                    Text(String(format: NSLocalizedString("profiles.count_limit %lld %lld", comment: ""), entries.count, ProfileHistoryService.maxEntries))
                }
            }
        }
        .searchable(text: $searchText, prompt: "profiles.search_prompt")
        .navigationTitle("dashboard.recent_profiles")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !entries.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        ForEach(ProfileProtocolFilter.allCases, id: \.self) { filter in
                            Button {
                                protocolFilter = filter
                            } label: {
                                if protocolFilter == filter {
                                    Label(filter.label, systemImage: "checkmark")
                                } else {
                                    Text(filter.label)
                                }
                            }
                        }
                    } label: {
                        Label("profiles.filter", systemImage: "line.3.horizontal.decrease.circle")
                            .foregroundStyle(protocolFilter == .all ? AnyShapeStyle(.primary) : AnyShapeStyle(.tint))
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button(role: .destructive) {
                            showClearAllConfirm = true
                        } label: {
                            Label("profiles.clear_all", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .task {
            if let pendingId = UserDefaults.standard.string(forKey: "pendingQRProfileId") {
                UserDefaults.standard.removeObject(forKey: "pendingQRProfileId")
                if let match = entries.first(where: { $0.id.uuidString == pendingId }) {
                    qrContent = match.content
                    showQRCode = true
                }
            }
        }
        .sheet(isPresented: $showQRCode) {
            QRCodeView(profileContent: qrContent)
        }
        .alert(
            "profiles.remove_confirm",
            isPresented: Binding(
                get: { entryPendingDeletion != nil },
                set: { if !$0 { entryPendingDeletion = nil } }
            )
        ) {
            Button("delete", role: .destructive) {
                if let entry = entryPendingDeletion {
                    ProfileHistoryService.shared.remove(id: entry.id)
                    entries = ProfileHistoryService.shared.entries
                }
                entryPendingDeletion = nil
            }
            Button("cancel", role: .cancel) { entryPendingDeletion = nil }
        }
        .alert("profiles.clear_all_confirm", isPresented: $showClearAllConfirm) {
            Button("profiles.clear_all", role: .destructive) {
                ProfileHistoryService.shared.clearAll()
                entries = []
            }
            Button("cancel", role: .cancel) {}
        }
    }

    private func reimport(_ entry: ProfileHistoryEntry) {
        let proto = VPNProtocol(rawValue: entry.vpnProtocol) ?? .wireguard
        let tmpURL = FileManager.default.temporaryDirectory.appendingPathComponent(entry.filename)
        try? entry.content.write(to: tmpURL, atomically: true, encoding: .utf8)
        VPNProfileImporter.shared.presentOpenIn(url: tmpURL, vpnProtocol: proto) {
            try? FileManager.default.removeItem(at: tmpURL)
        }
    }
}

struct ProfileHistoryRow: View {
    let entry: ProfileHistoryEntry

    private var subtitle: String {
        var parts = [VPNProtocol(rawValue: entry.vpnProtocol)?.displayName ?? entry.vpnProtocol]
        if let port = entry.port { parts.append("\(port)") }
        if let deviceName = entry.deviceName, !deviceName.isEmpty { parts.append(deviceName) }
        return parts.joined(separator: " · ")
    }

    var body: some View {
        HStack(spacing: 12) {
            if let code = entry.countryCode {
                FlagBadge(countryCode: code, size: 28)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.serverName)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                HStack(spacing: 4) {
                    if let proto = VPNProtocol(rawValue: entry.vpnProtocol) {
                        Image(proto.iconAssetName)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 12, height: 12)
                    }
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Text(entry.date.relativeShortString)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
    }
}
