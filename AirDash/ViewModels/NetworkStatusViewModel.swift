import SwiftUI

enum ServerSortOrder: String, CaseIterable {
    case load, loadDesc, name, ping

    var label: LocalizedStringKey {
        switch self {
        case .load:     "sort.load_asc"
        case .loadDesc: "sort.load_desc"
        case .name:     "sort.name"
        case .ping:     "sort.ping"
        }
    }

    var icon: String {
        switch self {
        case .load:     "arrow.up.circle"
        case .loadDesc: "arrow.down.circle"
        case .name:     "textformat.abc"
        case .ping:     "antenna.radiowaves.left.and.right"
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
    @Published var sortOrder: ServerSortOrder {
        didSet { UserDefaults.standard.set(sortOrder.rawValue, forKey: "serverSortOrder") }
    }
    @Published var favoriteIds: Set<String> {
        didSet { UserDefaults.standard.set(Array(favoriteIds), forKey: "favoriteServerIds") }
    }
    @Published var latencies: [String: Int] = [:]
    @Published var measuredIds: Set<String> = []

    init() {
        let saved = UserDefaults.standard.string(forKey: "serverSortOrder") ?? ""
        sortOrder = ServerSortOrder(rawValue: saved) ?? .load
        let savedFavorites = UserDefaults.standard.stringArray(forKey: "favoriteServerIds") ?? []
        favoriteIds = Set(savedFavorites)
    }

    var favoriteServers: [AirVPNServer] {
        (statusResponse?.servers ?? []).filter { favoriteIds.contains($0.id) }
    }

    var isFavoritesSectionVisible: Bool {
        !favoriteServers.isEmpty && searchText.isEmpty && selectedContinent == nil
    }

    var mainServers: [AirVPNServer] {
        isFavoritesSectionVisible
            ? filteredServers.filter { !favoriteIds.contains($0.id) }
            : filteredServers
    }

    func toggleFavorite(_ id: String) {
        if favoriteIds.contains(id) {
            favoriteIds.remove(id)
        } else {
            favoriteIds.insert(id)
        }
    }

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
        case .ping:
            servers.sort {
                switch (latencies[$0.id], latencies[$1.id]) {
                case let (a?, b?): return a < b
                case (_?, nil): return true
                default: return false
                }
            }
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
            if let servers = statusResponse?.servers {
                SharedDataService.writeServerNames(servers.map(\.publicName))
            }
        } catch is CancellationError {
            // ignore
        } catch let error as AppError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func measureLatencies() async {
        guard let servers = statusResponse?.servers else { return }
        latencies = [:]
        measuredIds = []
        await withTaskGroup(of: (String, Int?).self) { group in
            for server in servers {
                let ips = [server.ipV4In1, server.ipV4In2].compactMap { $0 }
                guard !ips.isEmpty else {
                    measuredIds.insert(server.id)
                    continue
                }
                group.addTask {
                    let ms = await PingService.ping(hosts: ips)
                    return (server.id, ms)
                }
            }
            for await (id, ms) in group {
                if let ms { latencies[id] = ms }
                measuredIds.insert(id)
            }
        }
    }

    func writeSharedFavoriteServers() {
        let servers = favoriteServers.map {
            SharedServerData(
                id: $0.id,
                name: $0.publicName,
                countryCode: $0.countryCode,
                location: $0.location,
                load: Int($0.currentLoad),
                users: $0.users,
                isHealthy: $0.health == .ok,
                latencyMs: latencies[$0.id]
            )
        }
        SharedDataService.writeFavoriteServers(servers)
    }

    func computeBestServer(for continent: String? = nil) -> AirVPNServer? {
        guard let servers = statusResponse?.servers else { return nil }
        let pool = continent == nil ? servers : servers.filter { $0.continent == continent }
        return pool
            .filter { $0.health == .ok }
            .compactMap { server -> (AirVPNServer, Double)? in
                guard let ping = latencies[server.id] else { return nil }
                let score = Double(ping) * (1.0 + server.currentLoad / 100.0)
                return (server, score)
            }
            .min(by: { $0.1 < $1.1 })
            .map(\.0)
    }
}
