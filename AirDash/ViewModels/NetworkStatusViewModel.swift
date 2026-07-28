import SwiftUI

enum ServerSortOrder: String, CaseIterable {
    case load, loadDesc, name, users

    var label: LocalizedStringKey {
        switch self {
        case .load:     "sort.load_asc"
        case .loadDesc: "sort.load_desc"
        case .name:     "sort.name"
        case .users:    "sort.users"
        }
    }

    var icon: String {
        switch self {
        case .load:     "arrow.up.circle"
        case .loadDesc: "arrow.down.circle"
        case .name:     "textformat.abc"
        case .users:    "person.3"
        }
    }
}

@MainActor
final class NetworkStatusViewModel: ObservableObject {
    @Published var statusResponse: AirVPNStatusResponse? = nil
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    @Published var searchText: String = ""
    @Published var selectedContinent: String? = nil
    @Published var sortOrder: ServerSortOrder = .load

    var filteredServers: [AirVPNServer] {
        var servers = statusResponse?.servers ?? []
        if let continent = selectedContinent {
            servers = servers.filter { $0.continent == continent }
        }
        if !searchText.isEmpty {
            servers = servers.filter {
                $0.publicName.localizedCaseInsensitiveContains(searchText) ||
                $0.countryName.localizedCaseInsensitiveContains(searchText) ||
                $0.location.localizedCaseInsensitiveContains(searchText)
            }
        }
        switch sortOrder {
        case .load:     servers.sort { $0.currentLoad < $1.currentLoad }
        case .loadDesc: servers.sort { $0.currentLoad > $1.currentLoad }
        case .name:     servers.sort { $0.publicName < $1.publicName }
        case .users:    servers.sort { $0.users > $1.users }
        }
        return servers
    }

    var continents: [String] {
        Array(Set(statusResponse?.servers.map(\.continent) ?? [])).sorted()
    }

    var healthyServersCount: Int {
        statusResponse?.servers.filter { $0.health == .ok }.count ?? 0
    }

    var averageLoad: Int {
        let servers = statusResponse?.servers ?? []
        guard !servers.isEmpty else { return 0 }
        return Int(servers.map(\.currentLoad).reduce(0, +) / Double(servers.count))
    }

    func load(forceRefresh: Bool = false) async {
        isLoading = true
        errorMessage = nil
        do {
            statusResponse = try await AirVPNAPIClient.shared.getStatus(forceRefresh: forceRefresh)
        } catch is CancellationError {
            // ignore
        } catch let error as AppError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
