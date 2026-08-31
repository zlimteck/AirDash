import SwiftUI
import NetworkExtension

struct DashboardView: View {
    @EnvironmentObject var appState: AppState
    #if VPN_ENABLED
    @EnvironmentObject var tunnelManager: VPNTunnelManager
    #endif
    @StateObject private var vm = DashboardViewModel()
    @State private var showAllProfiles = false
    @State private var selectedSessionServer: AirVPNServer? = nil

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
            .navigationDestination(isPresented: $showAllProfiles) {
                AllProfilesView()
            }
            .navigationDestination(item: $selectedSessionServer) { server in
                ServerDetailView(server: server)
            }
        }
        .task(id: appState.apiKey) {
            vm.reset()
            await vm.load(apiKey: appState.apiKey)
            if UserDefaults.standard.bool(forKey: "pendingShowProfiles") {
                UserDefaults.standard.removeObject(forKey: "pendingShowProfiles")
                showAllProfiles = true
            }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                guard !Task.isCancelled, !vm.activeSessions.isEmpty else { continue }
                await vm.silentRefresh(apiKey: appState.apiKey)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .showRecentProfiles).receive(on: DispatchQueue.main)) { _ in
            showAllProfiles = true
        }
    }

    private var isAccountCardVPNActive: Bool {
        #if VPN_ENABLED
        vm.isVPNActiveOnDevice || tunnelManager.status == .connected
        #else
        vm.isVPNActiveOnDevice
        #endif
    }

    #if VPN_ENABLED
    private var nativeTunnelStatusText: LocalizedStringKey {
        switch tunnelManager.status {
        case .connected: "tunnel.status.connected"
        case .connecting: "tunnel.status.connecting"
        case .reasserting: "tunnel.status.reasserting"
        case .disconnecting: "tunnel.status.disconnecting"
        default: "tunnel.status.disconnected"
        }
    }
    #endif

    private func openServerDetail(for session: AirVPNSession) async {
        guard let name = session.serverName else { return }
        guard let status = try? await AirVPNAPIClient.shared.getStatus() else { return }
        selectedSessionServer = status.servers.first {
            $0.publicName.lowercased() == name.lowercased()
        }
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
                        isVPNActive: isAccountCardVPNActive
                    )
                    .listRowInsets(EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16))
                    .listRowSeparator(.hidden)
                }
            }

            #if VPN_ENABLED
            if tunnelManager.status != .invalid && tunnelManager.status != .disconnected {
                Section {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill((tunnelManager.status == .connected ? Color.green : Color.secondary).opacity(0.15))
                                .frame(width: 34, height: 34)
                            Image(systemName: "lock.shield.fill")
                                .font(.subheadline)
                                .foregroundStyle(tunnelManager.status == .connected ? .green : .secondary)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("tunnel.title")
                                .font(.subheadline.bold())
                            Text(nativeTunnelStatusText)
                                .font(.caption)
                                .foregroundStyle(tunnelManager.status == .connected ? .green : .secondary)
                        }
                        Spacer()
                        if tunnelManager.status == .connecting || tunnelManager.status == .reasserting || tunnelManager.status == .disconnecting {
                            ProgressView()
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 16))
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        if tunnelManager.status == .connected {
                            Button(role: .destructive) {
                                Task {
                                    await tunnelManager.disconnect()
                                    await vm.load(apiKey: appState.apiKey, forceRefresh: true)
                                }
                            } label: {
                                Label("tunnel.disconnect", systemImage: "xmark.circle.fill")
                            }
                        }
                    }
                }
            }
            #endif

            if vm.userInfo != nil {
                Section {
                    if vm.activeSessions.isEmpty {
                        HStack {
                            Image(systemName: "shield.slash")
                                .font(.title2)
                                .foregroundStyle(.secondary)
                            Text("dashboard.no_sessions")
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                    } else {
                        ForEach(vm.activeSessions) { session in
                            SessionRowView(session: session)
                                .padding(.vertical, 4)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    Task { await openServerDetail(for: session) }
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) {
                                        Task {
                                            await vm.disconnectSession(session, apiKey: appState.apiKey)
                                            #if VPN_ENABLED
                                            if session.exitIP != nil, session.exitIP == vm.currentIP {
                                                await tunnelManager.disconnect()
                                            }
                                            #endif
                                        }
                                    } label: {
                                        Label("session.disconnect", systemImage: "xmark.circle.fill")
                                    }
                                }
                        }
                    }
                } header: {
                    Text("dashboard.active_sessions")
                }
            }

            // Profile history — link to full list
            if !ProfileHistoryService.shared.entries.isEmpty {
                Section {
                    NavigationLink {
                        AllProfilesView()
                    } label: {
                        Text("dashboard.view_recent_profiles")
                    }
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
        return Date(timeIntervalSince1970: Double(unix)).relativeShortString
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
