import SwiftUI

final class AppState: ObservableObject, @unchecked Sendable {
    @Published var isAuthenticated: Bool = false
    @Published var apiKey: String = ""
    @Published var selectedTab: Int = 1
    @Published var accounts: [Account] = []
    @Published var activeAccountId: String? = nil

    private let activeAccountKey = "activeAccountId"

    init() {
        migrateLegacyKeyIfNeeded()

        accounts = KeychainService.shared.loadAccounts()
        activeAccountId = UserDefaults.standard.string(forKey: activeAccountKey)

        if let active = accounts.first(where: { $0.id == activeAccountId }) ?? accounts.first {
            apiKey = active.apiKey
            activeAccountId = active.id
            isAuthenticated = true
            refreshLoginIfNeeded(for: active)
        }
    }

    /// Migrated (pre-multi-account) accounts have an empty login. Fetch it once
    /// in the background so Manage Accounts doesn't show a blank "—".
    private func refreshLoginIfNeeded(for account: Account) {
        guard account.login.isEmpty else { return }
        Task {
            guard let response = try? await AirVPNAPIClient.shared.validateAPIKey(account.apiKey) else { return }
            await MainActor.run {
                guard let index = self.accounts.firstIndex(where: { $0.id == account.id }) else { return }
                self.accounts[index] = Account(id: account.id, apiKey: account.apiKey, login: response.user.login)
                try? KeychainService.shared.saveAccounts(self.accounts)
            }
        }
    }

    private func migrateLegacyKeyIfNeeded() {
        guard KeychainService.shared.loadAccounts().isEmpty,
              let legacyKey = KeychainService.shared.loadAPIKey() else { return }
        let account = Account(apiKey: legacyKey, login: "")
        try? KeychainService.shared.saveAccounts([account])
        UserDefaults.standard.set(account.id, forKey: activeAccountKey)
        KeychainService.shared.deleteAPIKey()
        migrateLegacyNetworkPreferences(to: account.id)
    }

    /// Sort order and favorites used to be global (single-account era). Scope the
    /// existing values to the migrated account so they aren't silently lost.
    private func migrateLegacyNetworkPreferences(to accountId: String) {
        let defaults = UserDefaults.standard
        if let sortOrder = defaults.string(forKey: "serverSortOrder") {
            defaults.set(sortOrder, forKey: "serverSortOrder_\(accountId)")
            defaults.removeObject(forKey: "serverSortOrder")
        }
        if let favorites = defaults.stringArray(forKey: "favoriteServerIds") {
            defaults.set(favorites, forKey: "favoriteServerIds_\(accountId)")
            defaults.removeObject(forKey: "favoriteServerIds")
        }
    }

    func signIn(with key: String, login: String) {
        let account = Account(apiKey: key, login: login)
        accounts.append(account)
        try? KeychainService.shared.saveAccounts(accounts)
        setActiveAccount(account)
    }

    func addAccount(key: String, login: String) {
        let account = Account(apiKey: key, login: login)
        accounts.append(account)
        try? KeychainService.shared.saveAccounts(accounts)
        setActiveAccount(account)
    }

    func switchAccount(to accountId: String) {
        guard let account = accounts.first(where: { $0.id == accountId }) else { return }
        setActiveAccount(account)
    }

    func removeAccount(_ accountId: String) {
        accounts.removeAll { $0.id == accountId }
        try? KeychainService.shared.saveAccounts(accounts)

        if activeAccountId == accountId {
            if let next = accounts.first {
                setActiveAccount(next)
            } else {
                signOut()
            }
        }
    }

    private func setActiveAccount(_ account: Account) {
        apiKey = account.apiKey
        activeAccountId = account.id
        isAuthenticated = true
        UserDefaults.standard.set(account.id, forKey: activeAccountKey)
        refreshLoginIfNeeded(for: account)
    }

    func signOut() {
        accounts = []
        try? KeychainService.shared.saveAccounts([])
        UserDefaults.standard.removeObject(forKey: activeAccountKey)
        apiKey = ""
        activeAccountId = nil
        isAuthenticated = false
    }
}
