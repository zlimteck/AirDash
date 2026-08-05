import SwiftUI

struct ManageAccountsView: View {
    @EnvironmentObject var appState: AppState
    @State private var showAddAccount = false
    @State private var accountPendingDeletion: Account? = nil

    var body: some View {
        List {
            Section {
                ForEach(appState.accounts) { account in
                    Button {
                        guard account.id != appState.activeAccountId else { return }
                        appState.switchAccount(to: account.id)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(account.login.isEmpty ? "—" : account.login)
                                    .foregroundStyle(.primary)
                                Text(maskedKey(account.apiKey))
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if account.id == appState.activeAccountId {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.tint)
                            }
                        }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            accountPendingDeletion = account
                        } label: {
                            Label("delete", systemImage: "trash")
                        }
                    }
                }
            } footer: {
                Text("settings.manage_accounts.footer")
            }
        }
        .navigationTitle("settings.manage_accounts")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showAddAccount = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showAddAccount) {
            AddAccountView()
                .environmentObject(appState)
        }
        .alert(
            "settings.remove_account_confirm",
            isPresented: Binding(
                get: { accountPendingDeletion != nil },
                set: { if !$0 { accountPendingDeletion = nil } }
            )
        ) {
            Button("delete", role: .destructive) {
                if let account = accountPendingDeletion {
                    appState.removeAccount(account.id)
                }
                accountPendingDeletion = nil
            }
            Button("cancel", role: .cancel) { accountPendingDeletion = nil }
        }
    }

    private func maskedKey(_ key: String) -> String {
        guard key.count > 8 else { return key }
        return "\(key.prefix(4))…\(key.suffix(4))"
    }
}

struct AddAccountView: View {
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
            .navigationTitle("settings.add_account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("settings.save") {
                        Task { await validateAndAdd() }
                    }
                    .disabled(newKey.isEmpty || isValidating)
                    .overlay {
                        if isValidating { ProgressView().scaleEffect(0.7) }
                    }
                }
            }
        }
    }

    private func validateAndAdd() async {
        isValidating = true
        errorMessage = nil
        let key = newKey.trimmingCharacters(in: .whitespacesAndNewlines)

        if appState.accounts.contains(where: { $0.apiKey == key }) {
            errorMessage = String(localized: "settings.error.account_exists")
            isValidating = false
            return
        }

        do {
            let response = try await AirVPNAPIClient.shared.validateAPIKey(key)
            appState.addAccount(key: key, login: response.user.login)
            dismiss()
        } catch let error as AppError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
        isValidating = false
    }
}
