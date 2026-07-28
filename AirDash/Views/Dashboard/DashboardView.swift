import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var vm = DashboardViewModel()
    @Environment(\.horizontalSizeClass) private var sizeClass

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
        .task { await vm.load(apiKey: appState.apiKey) }
    }

    private var dashboardContent: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                if let error = vm.errorMessage {
                    ErrorBanner(message: error)
                }

                // Account card
                if let userInfo = vm.userInfo {
                    AccountCard(
                        user: userInfo.user,
                        warning: vm.expirationWarning,
                        sessionCount: vm.activeSessions.count,
                        currentIP: vm.currentIP,
                        isVPNActive: vm.isVPNActiveOnDevice
                    )
                    .padding(.horizontal)
                }

                // Active sessions
                if !vm.activeSessions.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("dashboard.active_sessions")
                            .font(.headline)
                            .padding(.horizontal)

                        if sizeClass == .regular {
                            // iPad : grille 2 colonnes
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                                ForEach(vm.activeSessions) { session in
                                    SessionRowView(session: session) {
                                        await vm.disconnectSession(session, apiKey: appState.apiKey)
                                    }
                                }
                            }
                            .padding(.horizontal)
                        } else {
                            // iPhone : colonne unique
                            ForEach(vm.activeSessions) { session in
                                SessionRowView(session: session) {
                                    await vm.disconnectSession(session, apiKey: appState.apiKey)
                                }
                                .padding(.horizontal)
                            }
                        }
                    }
                } else if vm.userInfo != nil {
                    GlassCard {
                        HStack {
                            Image(systemName: "shield.slash")
                                .font(.title2)
                                .foregroundStyle(.secondary)
                            Text("dashboard.no_sessions")
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
        .refreshable { await vm.load(apiKey: appState.apiKey, forceRefresh: true) }
    }
}

struct AccountCard: View {
    let user: AirVPNUser
    let warning: Bool
    let sessionCount: Int
    let currentIP: String?
    let isVPNActive: Bool

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

    var body: some View {
        GlassCard {
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
                HStack(spacing: 6) {
                    Image(systemName: isVPNActive ? "shield.fill" : "shield.slash")
                        .font(.caption)
                        .foregroundStyle(isVPNActive ? .green : .secondary)
                    Text(currentIP ?? "...")
                        .font(.caption.monospaced())
                        .foregroundStyle(.primary)
                    Spacer()
                    Text(isVPNActive ? "dashboard.vpn_on" : "dashboard.vpn_off")
                        .font(.caption2)
                        .foregroundStyle(isVPNActive ? .green : .secondary)
                }

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
                        Text(user.registerDate ?? "-")
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
}
