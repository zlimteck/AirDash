import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var vm = DashboardViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if vm.isLoading && vm.userInfo == nil {
                    VStack { LoadingOverlay(label: "dashboard.loading") }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    dashboardContent
                }
            }
            .navigationTitle("tab.dashboard")
            .navigationBarTitleDisplayMode(.large)
        }
        .task {
            await vm.load(apiKey: appState.apiKey)
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                guard !Task.isCancelled, !vm.activeSessions.isEmpty else { continue }
                await vm.silentRefresh(apiKey: appState.apiKey)
            }
        }
    }

    private func reimportProfile(_ entry: ProfileHistoryEntry) {
        let proto = VPNProtocol(rawValue: entry.vpnProtocol) ?? .wireguard
        let tmpURL = FileManager.default.temporaryDirectory.appendingPathComponent(entry.filename)
        try? entry.content.write(to: tmpURL, atomically: true, encoding: .utf8)
        VPNProfileImporter.shared.presentOpenIn(url: tmpURL, vpnProtocol: proto)
    }

    private var dashboardContent: some View {
        List {
            if let error = vm.errorMessage {
                Section {
                    ErrorBanner(message: error)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
            }

            if let userInfo = vm.userInfo {
                Section {
                    AccountCard(
                        user: userInfo.user,
                        warning: vm.expirationWarning,
                        sessionCount: vm.activeSessions.count,
                        currentIP: vm.currentIP,
                        isVPNActive: vm.isVPNActiveOnDevice
                    )
                    .listRowInsets(EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16))
                    .listRowSeparator(.hidden)
                }
            }

            if vm.userInfo != nil {
                if vm.activeSessions.isEmpty {
                    Section {
                        HStack {
                            Image(systemName: "shield.slash")
                                .font(.title2)
                                .foregroundStyle(.secondary)
                            Text("dashboard.no_sessions")
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .listRowInsets(EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16))
                        .listRowSeparator(.hidden)
                    } header: {
                        Text("dashboard.active_sessions")
                    }
                } else {
                    ForEach(Array(vm.activeSessions.enumerated()), id: \.element.id) { index, session in
                        Section {
                            SessionRowView(session: session)
                                .listRowInsets(EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16))
                                .listRowSeparator(.hidden)
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) {
                                        Task { await vm.disconnectSession(session, apiKey: appState.apiKey) }
                                    } label: {
                                        Label("session.disconnect", systemImage: "xmark.circle.fill")
                                    }
                                }
                        } header: {
                            if index == 0 {
                                Text("dashboard.active_sessions")
                            }
                        }
                    }
                }
            }

            // Profile history — horizontal scroll
            let history = ProfileHistoryService.shared.entries
            if !history.isEmpty {
                Section {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(history.prefix(8)) { entry in
                                RecentProfileCard(entry: entry) {
                                    reimportProfile(entry)
                                }
                                .containerRelativeFrame(.horizontal, count: 2, span: 1, spacing: 12)
                            }
                        }
                        .scrollTargetLayout()
                        .padding(.vertical, 12)
                    }
                    .scrollTargetBehavior(.viewAligned)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                } header: {
                    Text("dashboard.recent_profiles")
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color(.systemGroupedBackground))
        .refreshable { await vm.load(apiKey: appState.apiKey, forceRefresh: true) }
    }
}

struct RecentProfileCard: View {
    let entry: ProfileHistoryEntry
    let onReimport: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "doc.badge.arrow.up")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    onReimport()
                } label: {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 6) {
                if let code = entry.countryCode {
                    FlagBadge(countryCode: code, size: 18)
                }
                Text(entry.serverName)
                    .font(.subheadline.bold())
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            Text(VPNProtocol(rawValue: entry.vpnProtocol)?.displayName ?? entry.vpnProtocol)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(relativeTime(entry.date))
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func relativeTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        formatter.dateTimeStyle = .named
        let components = Calendar.current.dateComponents([.minute, .hour, .day, .month, .year], from: date, to: Date())
        if (components.minute ?? 0) < 1 && (components.hour ?? 0) == 0 && (components.day ?? 0) == 0 {
            return String(localized: "detail.just_now")
        }
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

struct AccountCard: View {
    let user: AirVPNUser
    let warning: Bool
    let sessionCount: Int
    let currentIP: String?
    let isVPNActive: Bool
    @State private var ipCopied = false

    var expirationText: String {
        if let days = user.expirationDays {
            return String(format: NSLocalizedString("dashboard.expires_in_days", comment: ""), days)
        }
        return user.expirationDate ?? "-"
    }

    var lastSeenText: String {
        guard let unix = user.lastAttemptUnix else { return "-" }
        let date = Date(timeIntervalSince1970: Double(unix))
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    var registerDateText: String {
        guard let raw = user.registerDate else { return "-" }
        let parsers = ["yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd"]
        let input = DateFormatter()
        let output = DateFormatter()
        output.dateFormat = "dd/MM/yyyy"
        for format in parsers {
            input.dateFormat = format
            if let date = input.date(from: raw) {
                return output.string(from: date)
            }
        }
        return raw
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 8) {
                    Text(user.login)
                        .font(.title3.bold())
                    if user.premium == true {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(.yellow)
                    }
                    Spacer()
                    Circle()
                        .fill(isVPNActive ? Color.green : Color.secondary.opacity(0.4))
                        .frame(width: 10, height: 10)
                }

                Divider()

                // Current IP
                Button {
                    guard let ip = currentIP else { return }
                    UIPasteboard.general.string = ip
                    withAnimation { ipCopied = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation { ipCopied = false }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: isVPNActive ? "shield.fill" : "shield.slash")
                            .font(.caption)
                            .foregroundStyle(isVPNActive ? .green : .secondary)
                        Text(currentIP ?? "...")
                            .font(.caption.monospaced())
                            .foregroundStyle(.primary)
                        Spacer()
                        if ipCopied {
                            Image(systemName: "checkmark")
                                .font(.caption2)
                                .foregroundStyle(.green)
                                .transition(.scale.combined(with: .opacity))
                        }
                        Text(isVPNActive ? "dashboard.vpn_on" : "dashboard.vpn_off")
                            .font(.caption2)
                            .foregroundStyle(isVPNActive ? .green : .secondary)
                    }
                }
                .buttonStyle(.plain)

                Divider()

                // Row 1 : expiration + credits
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("dashboard.expiration")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(expirationText)
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(warning ? .orange : .primary)
                    }

                    Spacer()

                    if let credits = user.credits, credits > 0 {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("dashboard.credits")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("\(credits)")
                                .font(.subheadline.monospacedDigit())
                        }
                    }
                }

                Divider()

                // Row 2 : member since + sessions + last seen
                HStack(alignment: .top, spacing: 0) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("dashboard.member_since")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(registerDateText)
                            .font(.caption.monospacedDigit())
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(alignment: .center, spacing: 2) {
                        Text("dashboard.sessions")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(sessionCount)")
                            .font(.caption.monospacedDigit())
                    }
                    .frame(maxWidth: .infinity, alignment: .center)

                    VStack(alignment: .trailing, spacing: 2) {
                        Text("dashboard.last_seen")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(lastSeenText)
                            .font(.caption)
                            .multilineTextAlignment(.trailing)
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }

                if warning {
                    Label("dashboard.expiration_warning", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
        }
    }
}
