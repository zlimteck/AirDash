import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @AppStorage("appTheme") private var appTheme: String = "system"
    @State private var showSignOutAlert = false
    @State private var showRotateKeySheet = false

    var body: some View {
        NavigationStack {
            List {
                // Account section
                Section {
                    HStack {
                        Label("settings.api_key", systemImage: "key.fill")
                        Spacer()
                        Text(maskedAPIKey)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                    }

                    Button {
                        showRotateKeySheet = true
                    } label: {
                        Label("settings.rotate_key", systemImage: "arrow.triangle.2.circlepath")
                    }

                    Link(destination: URL(string: "https://airvpn.org/buy/")!) {
                        Label {
                            Text("settings.renew_subscription")
                        } icon: {
                            Image(systemName: "arrow.clockwise")
                                .foregroundStyle(.blue)
                        }
                    }
                } header: {
                    Text("settings.section.account")
                }

                // Appearance section
                Section {
                    Picker("settings.theme", selection: $appTheme) {
                        Text("settings.theme.system").tag("system")
                        Text("settings.theme.light").tag("light")
                        Text("settings.theme.dark").tag("dark")
                    }

                } header: {
                    Text("settings.section.appearance")
                }

                // About section
                Section {
                    HStack {
                        Text("settings.app_version")
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
                    Link(destination: URL(string: "https://github.com/zlimteck/AirDash")!) {
                        Label {
                            Text("settings.github")
                        } icon: {
                            Image("github-mark")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 20, height: 20)
                        }
                    }
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
                        Label("settings.sign_out", systemImage: "rectangle.portrait.and.arrow.right")
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("tab.settings")
            .navigationBarTitleDisplayMode(.large)
            .alert("settings.sign_out_confirm", isPresented: $showSignOutAlert) {
                Button("settings.sign_out", role: .destructive) { appState.signOut() }
                Button("cancel", role: .cancel) {}
            } message: {
                Text("settings.sign_out_message")
            }
            .sheet(isPresented: $showRotateKeySheet) {
                RotateAPIKeyView()
                    .environmentObject(appState)
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

struct RotateAPIKeyView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var newKey: String = ""
    @State private var isValidating = false
    @State private var errorMessage: String? = nil

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("onboarding.apikey.placeholder", text: $newKey)
                        .textContentType(.password)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                } header: {
                    Text("settings.new_api_key")
                } footer: {
                    if let error = errorMessage {
                        Label(error, systemImage: "xmark.circle.fill")
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("settings.rotate_key")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("settings.save") {
                        Task { await validateAndSave() }
                    }
                    .disabled(newKey.isEmpty || isValidating)
                    .overlay {
                        if isValidating { ProgressView().scaleEffect(0.7) }
                    }
                }
            }
        }
    }

    private func validateAndSave() async {
        isValidating = true
        errorMessage = nil
        let key = newKey.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            _ = try await AirVPNAPIClient.shared.validateAPIKey(key)
            try KeychainService.shared.saveAPIKey(key)
            appState.signIn(with: key)
            dismiss()
        } catch let error as AppError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
        isValidating = false
    }
}
