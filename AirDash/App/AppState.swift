import SwiftUI

final class AppState: ObservableObject {
    @Published var isAuthenticated: Bool = false
    @Published var apiKey: String = ""
    @Published var selectedTab: Int = 1

    init() {
        if let key = KeychainService.shared.loadAPIKey() {
            apiKey = key
            isAuthenticated = true
        }
    }

    func signIn(with key: String) {
        apiKey = key
        isAuthenticated = true
    }

    func signOut() {
        KeychainService.shared.deleteAPIKey()
        apiKey = ""
        isAuthenticated = false
    }
}
