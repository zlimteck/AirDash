import SwiftUI

final class AppState: ObservableObject {
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
        }
    }

    private func migrateLegacyKeyIfNeeded() {
        guard KeychainService.shared.loadAccounts().isEmpty,
              let legacyKey = KeychainService.shared.loadAPIKey() else { return }
        let account = Account(apiKey: legacyKey, login: "")
        try? KeychainService.shared.saveAccounts([account])
        UserDefaults.standard.set(account.id, forKey: activeAccountKey)
        KeychainService.shared.deleteAPIKey()
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
