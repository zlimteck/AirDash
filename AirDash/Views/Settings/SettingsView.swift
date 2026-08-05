import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @AppStorage("appTheme") private var appTheme: String = "system"
    @AppStorage("selectedAppIcon") private var selectedAppIcon: String = "Default"
    @AppStorage("appLockEnabled") private var appLockEnabled = false
    @State private var showSignOutAlert = false

    var body: some View {
        NavigationStack {
            List {
                // Account section
                Section {
                    NavigationLink {
                        ManageAccountsView()
                    } label: {
                        HStack {
                            Label("settings.manage_accounts", systemImage: "person.2.fill")
                            Spacer()
                            Text(maskedAPIKey)
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                        }
                    }

                    Link(destination: URL(string: "https://airvpn.org/buy/")!) {
                        Label("settings.renew_subscription", systemImage: "arrow.clockwise")
                    }
                    .foregroundStyle(.primary)
                } header: {
                    Text("settings.section.account")
                }

                // VPN section
                Section {
                    NavigationLink {
                        ManageDevicesView()
                    } label: {
                        Label("devices.title", systemImage: "laptopcomputer.and.iphone")
                    }

                    NavigationLink {
                        DNSListsView()
                    } label: {
                        Label("dns.title", systemImage: "shield.lefthalf.filled")
                    }
                } header: {
                    Text("settings.section.vpn")
                }

                // Appearance section
                Section {
                    Picker(selection: $appTheme) {
                        Text("settings.theme.system").tag("system")
                        Text("settings.theme.light").tag("light")
                        Text("settings.theme.dark").tag("dark")
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "circle.lefthalf.filled")
                                .font(.system(size: 15, weight: .regular))
                                .foregroundStyle(.tint)
                            Text("settings.theme")
                                .foregroundStyle(.primary)
                        }
                    }
                    NavigationLink {
                        AppIconPickerView()
                    } label: {
                        HStack {
                            Label("settings.section.app_icon", systemImage: "app.badge")
                            Spacer()
                            Text(AppIconOption(rawValue: selectedAppIcon)?.label ?? "")
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("settings.section.appearance")
                }

                // Security section
                Section {
                    Toggle(isOn: $appLockEnabled) {
                        HStack(spacing: 12) {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 15, weight: .regular))
                                .foregroundStyle(.tint)
                            Text("settings.app_lock")
                                .foregroundStyle(.primary)
                        }
                    }
                    .onChange(of: appLockEnabled) { _, enabled in
                        if enabled {
                            Task {
                                let ok = await AppLockService.shared.verifyBiometrics()
                                if !ok { appLockEnabled = false }
                            }
                        }
                    }
                } header: {
                    Text("settings.section.security")
                }

                // About section
                Section {
                    HStack {
                        Label("settings.app_version", systemImage: "info.circle")
                        Spacer()
                        Text(appVersion)
                            .foregroundStyle(.secondary)
                    }
                    NavigationLink {
                        ChangelogView()
                    } label: {
                        Label("settings.changelog", systemImage: "list.bullet.clipboard")
                    }
                    NavigationLink {
                        CreditsView()
                    } label: {
                        Label("settings.credits", systemImage: "heart.fill")
                    }
                    Link(destination: URL(string: "https://airvpn.org")!) {
                        Label("settings.airvpn_website", systemImage: "safari")
                    }
                    .foregroundStyle(.primary)
                    Link(destination: URL(string: "https://github.com/zlimteck/AirDash")!) {
                        Label {
                            Text("settings.github")
                        } icon: {
                            Image("github-mark")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 15, height: 15)
                        }
                    }
                    .foregroundStyle(.primary)
                } header: {
                    Text("settings.section.about")
                } footer: {
                    Text("settings.disclaimer")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // Sign out
                Section {
                    Button(role: .destructive) {
                        showSignOutAlert = true
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .font(.system(size: 15, weight: .regular))
                                .foregroundStyle(.red)
                            Text("settings.sign_out")
                                .foregroundStyle(.red)
                        }
                    }
                }
            }
            .labelStyle(SettingsLabelStyle())
            .navigationTitle("tab.settings")
            .navigationBarTitleDisplayMode(.large)
            .alert("settings.sign_out_confirm", isPresented: $showSignOutAlert) {
                Button("settings.sign_out", role: .destructive) { appState.signOut() }
                Button("cancel", role: .cancel) {}
            } message: {
                Text("settings.sign_out_message")
            }
        }
    }

    private var maskedAPIKey: String {
        guard !appState.apiKey.isEmpty else { return "—" }
        let prefix = appState.apiKey.prefix(4)
        let suffix = appState.apiKey.suffix(4)
        return "\(prefix)…\(suffix)"
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}

enum AppIconOption: String, CaseIterable {
    case `default` = "Default"
    case classic = "AppIcon-Classic"
    case light = "AppIcon-Light"
    case purple = "AppIcon-Purple"
    case green = "AppIcon-Green"
    case red = "AppIcon-Red"
    case minimal = "AppIcon-Minimal"
    case minimalDark = "AppIcon-MinimalDark"

    var label: LocalizedStringKey {
        switch self {
        case .default: return "settings.icon.default"
        case .classic: return "settings.icon.classic"
        case .light: return "settings.icon.light"
        case .purple: return "settings.icon.purple"
        case .green: return "settings.icon.green"
        case .red: return "settings.icon.red"
        case .minimal: return "settings.icon.minimal"
        case .minimalDark: return "settings.icon.minimal_dark"
        }
    }

    var previewImageName: String {
        "IconPreview-\(rawValue)"
    }
}

private struct SettingsLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 12) {
            configuration.icon
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(.tint)
                .frame(width: 20, alignment: .center)
            configuration.title
                .foregroundStyle(.primary)
        }
    }
}

