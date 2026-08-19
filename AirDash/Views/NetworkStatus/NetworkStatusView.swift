import SwiftUI

struct NetworkStatusView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var vm = NetworkStatusViewModel()
    @State private var path = NavigationPath()
    @State private var pendingServerName: String? = nil
    @State private var bestServer: AirVPNServer? = nil
    @State private var cachedBestServer: SharedServerData? = SharedDataService.readBestServer()
    @State private var compareServers: [AirVPNServer] = []
    @State private var showComparison = false
    @State private var showTrends = false
    @State private var reliabilityByServer: [String: Double] = [:]

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if vm.isLoading && vm.statusResponse == nil {
                    VStack { LoadingOverlay(label: "network.loading") }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    serverList
                }
            }
            .navigationTitle("tab.network")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $vm.searchText, prompt: "network.search.prompt")
            .toolbar {
                if compareServers.count >= 2 {
                    ToolbarItem(placement: .topBarLeading) {
                        Button { showComparison = true } label: {
                            Label(
                                "\(String(localized: "compare.compare")) (\(compareServers.count))",
                                systemImage: "square.split.2x1"
                            )
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showTrends = true } label: {
                        Label("network.trends", systemImage: "chart.line.uptrend.xyaxis")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        ForEach(ServerSortOrder.allCases, id: \.self) { order in
                            Button {
                                vm.sortOrder = order
                            } label: {
                                Label(order.label, systemImage: order.icon)
                            }
                        }
                    } label: {
                        Label("sort", systemImage: "arrow.up.arrow.down")
                            .foregroundStyle(vm.sortOrder == .load ? AnyShapeStyle(.primary) : AnyShapeStyle(.tint))
                    }
                }
            }
        }
        .task(id: appState.activeAccountId) {
            vm.loadPreferences(accountId: appState.activeAccountId ?? "")
            await vm.load()
            await vm.measureLatencies()
            bestServer = vm.computeBestServer()
            writeSharedBestServer(bestServer)
            vm.writeSharedFavoriteServers()
            SpotlightService.indexFavoriteServers(vm.favoriteServers)
            await loadFavoritesReliability()
            if let name = UserDefaults.standard.string(forKey: "pendingOpenServer") {
                UserDefaults.standard.removeObject(forKey: "pendingOpenServer")
                navigateToServer(named: name)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .openServer).receive(on: DispatchQueue.main)) { notification in
            guard let name = notification.object as? String else { return }
            if vm.statusResponse != nil {
                navigateToServer(named: name)
            } else {
                pendingServerName = name
            }
        }
        .onChange(of: vm.isLoading) {
            if !vm.isLoading, let name = pendingServerName {
                pendingServerName = nil
                navigateToServer(named: name)
            }
        }
        .onChange(of: vm.selectedContinent) {
            bestServer = vm.computeBestServer(for: vm.selectedContinent)
        }
        .onChange(of: vm.favoriteIds) {
            vm.writeSharedFavoriteServers()
            SpotlightService.indexFavoriteServers(vm.favoriteServers)
            Task { await loadFavoritesReliability() }
        }
        .sheet(isPresented: $showComparison) {
            ServerComparisonView(
                servers: compareServers,
                latencies: vm.latencies,
                measuredIds: vm.measuredIds,
                onClear: { compareServers = [] }
            )
        }
    }

    private func localizedContinent(_ apiValue: String) -> LocalizedStringKey {
        switch apiValue {
        case "Europe":         return "continent.europe"
        case "America":        return "continent.america"
        case "North America":  return "continent.north_america"
        case "South America":  return "continent.south_america"
        case "Asia":           return "continent.asia"
        case "Oceania":        return "continent.oceania"
        case "Africa":         return "continent.africa"
        default:               return LocalizedStringKey(apiValue)
        }
    }

    private func toggleCompare(_ server: AirVPNServer) {
        if let idx = compareServers.firstIndex(of: server) {
            compareServers.remove(at: idx)
        } else if compareServers.count < 3 {
            compareServers.append(server)
        }
    }

    private func loadFavoritesReliability() async {
        guard !vm.favoriteServers.isEmpty else { return }
        guard let response = try? await AirVPNHistoryClient.shared.reliability(window: .oneDay) else { return }
        var byName: [String: Double] = [:]
        for entry in response.servers {
            byName[entry.serverName] = entry.okPercent
        }
        reliabilityByServer = byName
    }

    private func writeSharedBestServer(_ server: AirVPNServer?) {
        guard let server else {
            SharedDataService.writeBestServer(nil)
            return
        }
        SharedDataService.writeBestServer(SharedServerData(
            id: server.id,
            name: server.publicName,
            countryCode: server.countryCode,
            location: server.location,
            load: Int(server.currentLoad),
            users: server.users,
            isHealthy: server.health == .ok,
            latencyMs: vm.latencies[server.id]
        ))
    }

    private func navigateToServer(named name: String) {
        guard let server = vm.statusResponse?.servers.first(where: {
            $0.publicName.lowercased() == name.lowercased()
        }) else { return }
        path.append(server)
    }

    private var serverList: some View {
        List {
            // Error banner
            if let error = vm.errorMessage {
                Section {
                    ErrorBanner(message: error)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
            }

            // Summary cards
            if let status = vm.statusResponse, vm.searchText.isEmpty {
                Section {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            SummaryCard(
                                title: "network.total_servers",
                                value: "\(status.servers.count)",
                                icon: "server.rack",
                                color: .blue
                            )
                            SummaryCard(
                                title: "network.healthy_servers",
                                value: "\(vm.healthyServersCount)",
                                icon: "checkmark.shield.fill",
                                color: .green
                            )
                            SummaryCard(
                                title: "network.connected_users",
                                value: "\(status.planets.first?.users ?? 0)",
                                icon: "person.3.fill",
                                color: .cyan
                            )
                            SummaryCard(
                                title: "network.avg_load",
                                value: "\(vm.averageLoad)%",
                                icon: "gauge.with.needle",
                                color: vm.averageLoad > 70 ? .red : vm.averageLoad > 40 ? .orange : .mint
                            )
                            SummaryCard(
                                title: "network.countries",
                                value: "\(status.countries.count)",
                                icon: "globe",
                                color: .orange
                            )
                            SummaryCard(
                                title: "network.continents",
                                value: "\(status.continents.count)",
                                icon: "map.fill",
                                color: .purple
                            )
                        }
                        .scrollTargetLayout()
                        .padding(.vertical, 12)
                    }
                    .scrollTargetBehavior(.viewAligned)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
                .listSectionSpacing(8)
            }

            // Continent filter
            if !vm.continents.isEmpty && vm.searchText.isEmpty {
                Section {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ContinentChip(label: "network.all", selected: vm.selectedContinent == nil) {
                                vm.selectedContinent = nil
                            }
                            ForEach(vm.continents, id: \.self) { continent in
                                ContinentChip(
                                    label: localizedContinent(continent),
                                    selected: vm.selectedContinent == continent
                                ) {
                                    vm.selectedContinent = vm.selectedContinent == continent ? nil : continent
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .contentMargins(.leading, 16, for: .scrollContent)
                    .contentMargins(.trailing, 16, for: .scrollContent)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color(.systemGroupedBackground))
                    .listRowSeparator(.hidden)
                }
            }

            // Best server
            if let best = bestServer, vm.searchText.isEmpty {
                Section {
                    Button { path.append(best) } label: {
                        ServerRowView(
                            server: best,
                            latency: vm.latencies[best.id],
                            isMeasured: vm.measuredIds.contains(best.id),
                            isFavorite: vm.favoriteIds.contains(best.id)
                        )
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(Color.yellow.opacity(0.15))
                    .contextMenu {
                        Button { toggleCompare(best) } label: {
                            Label(
                                compareServers.contains(best) ? "compare.remove" : "compare.add",
                                systemImage: compareServers.contains(best) ? "minus.circle" : "plus.circle"
                            )
                        }
                        .disabled(!compareServers.contains(best) && compareServers.count >= 3)
                    }
                } header: {
                    Text("network.best_server")
                }
                .transition(.opacity)
            } else if let cached = cachedBestServer, vm.searchText.isEmpty {
                Section {
                    CachedBestServerRow(server: cached)
                        .listRowBackground(Color.yellow.opacity(0.08))
                } header: {
                    HStack(spacing: 6) {
                        Text("network.best_server")
                        ProgressView()
                            .scaleEffect(0.6)
                    }
                }
                .transition(.opacity)
            }

            // Favorites section
            if vm.isFavoritesSectionVisible {
                Section {
                    ForEach(vm.favoriteServers) { server in
                        Button { path.append(server) } label: {
                            ServerRowView(
                                server: server,
                                latency: vm.latencies[server.id],
                                isMeasured: vm.measuredIds.contains(server.id),
                                isFavorite: true,
                                reliabilityPercent: reliabilityByServer[server.id]
                            )
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button { toggleCompare(server) } label: {
                                Label(
                                    compareServers.contains(server) ? "compare.remove" : "compare.add",
                                    systemImage: compareServers.contains(server) ? "minus.circle" : "plus.circle"
                                )
                            }
                            .disabled(!compareServers.contains(server) && compareServers.count >= 3)
                            Divider()
                            Button(role: .destructive) {
                                vm.toggleFavorite(server.id)
                            } label: {
                                Label("favorites.remove", systemImage: "star.slash")
                            }
                        }
                    }
                } header: {
                    Text("favorites.section")
                }
            }

            // Server list
            Section {
                ForEach(vm.mainServers) { server in
                    Button { path.append(server) } label: {
                        ServerRowView(
                            server: server,
                            latency: vm.latencies[server.id],
                            isMeasured: vm.measuredIds.contains(server.id),
                            isFavorite: vm.favoriteIds.contains(server.id)
                        )
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button {
                            vm.toggleFavorite(server.id)
                        } label: {
                            Label(
                                vm.favoriteIds.contains(server.id) ? "favorites.remove" : "favorites.add",
                                systemImage: vm.favoriteIds.contains(server.id) ? "star.slash" : "star"
                            )
                        }
                        Divider()
                        Button { toggleCompare(server) } label: {
                            Label(
                                compareServers.contains(server) ? "compare.remove" : "compare.add",
                                systemImage: compareServers.contains(server) ? "minus.circle" : "plus.circle"
                            )
                        }
                        .disabled(!compareServers.contains(server) && compareServers.count >= 3)
                    }
                }
            } header: {
                Text(String(format: NSLocalizedString("network.servers %lld", comment: ""), vm.mainServers.count))
            }
        }
        .animation(.snappy, value: bestServer)
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color(.systemGroupedBackground))
        .refreshable {
            await vm.load(forceRefresh: true)
            await vm.measureLatencies()
            bestServer = vm.computeBestServer()
            writeSharedBestServer(bestServer)
            vm.writeSharedFavoriteServers()
            SpotlightService.indexFavoriteServers(vm.favoriteServers)
        }
        .navigationDestination(for: AirVPNServer.self) { server in
            ServerDetailView(server: server)
        }
        .navigationDestination(isPresented: $showTrends) {
            TrendsView()
        }
    }
}

struct SummaryCard: View {
    let title: LocalizedStringKey
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .center, spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
                .frame(height: 24)
            Text(value)
                .font(.title2.bold().monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(14)
        .containerRelativeFrame(.horizontal, count: 3, span: 1, spacing: 12)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct ContinentChip: View {
    let label: LocalizedStringKey
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .foregroundStyle(selected ? Color.accentColor : .primary)
        }
        .buttonStyle(.plain)
        .background(Color(.secondarySystemGroupedBackground), in: Capsule())
        .overlay {
            if selected {
                Capsule()
                    .fill(Color.accentColor.opacity(0.18))
                    .overlay {
                        Capsule()
                            .strokeBorder(Color.accentColor.opacity(0.5), lineWidth: 1)
                    }
                    .allowsHitTesting(false)
            }
        }
        .animation(.spring(duration: 0.2), value: selected)
    }
}
