import Foundation

struct Account: Codable, Identifiable, Equatable {
    let id: String
    let apiKey: String
    let login: String

    init(id: String = UUID().uuidString, apiKey: String, login: String) {
        self.id = id
        self.apiKey = apiKey
        self.login = login
    }
}
