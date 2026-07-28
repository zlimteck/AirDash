import SwiftUI

struct NetworkStatusView: View {
    @StateObject private var vm = NetworkStatusViewModel()

    var body: some View {
        NavigationStack {
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
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        ForEach(ServerSortOrder.allCases, id: \.self) { order in
                            Button {
                                vm.sortOrder = order
                            } label: {
                                Label(order.label, systemImage: order.icon)
                            }
                            .buttonStyle(.plain)
                        }
                    } label: {
                        Label("sort", systemImage: vm.sortOrder == .load ? "arrow.up.arrow.down" : "arrow.up.arrow.down.circle.fill")
                            .symbolRenderingMode(.hierarchical)
                    }
                }
            }
        }
        .task { await vm.load() }
    }

    private var serverList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                // Error banner
                if let error = vm.errorMessage {
                    ErrorBanner(message: error)
                        .padding(.top, 8)
                }

                // Summary cards
                if let status = vm.statusResponse, vm.searchText.isEmpty {
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
                    .contentMargins(.horizontal, 16, for: .scrollContent)
                    .scrollTargetBehavior(.viewAligned)
                }

                // Continent filter
                if !vm.continents.isEmpty && vm.searchText.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ContinentChip(label: "network.all", selected: vm.selectedContinent == nil) {
                                vm.selectedContinent = nil
                            }
                            ForEach(vm.continents, id: \.self) { continent in
                                ContinentChip(
                                    label: LocalizedStringKey(continent),
                                    selected: vm.selectedContinent == continent
                                ) {
                                    vm.selectedContinent = vm.selectedContinent == continent ? nil : continent
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 4)
                    }
                    .padding(.bottom, 8)
                }

                // Server list header
                Section {
                    ForEach(vm.filteredServers) { server in
                        NavigationLink(value: server) {
                            ServerRowView(server: server)
                                .padding(.horizontal)
                                .padding(.vertical, 10)
                        }
                        .buttonStyle(.plain)

                        Divider()
                            .padding(.leading, 66)
                            .padding(.trailing, 16)
                    }
                } header: {
                    Text(String(format: NSLocalizedString("network.servers %lld", comment: ""), vm.filteredServers.count))
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .padding(.horizontal)
                        .padding(.vertical, 6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .refreshable { await vm.load(forceRefresh: true) }
        .navigationDestination(for: AirVPNServer.self) { server in
            ServerDetailView(server: server)
        }
    }
}

struct SummaryCard: View {
    let title: LocalizedStringKey
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
                .frame(height: 24, alignment: .center)
            Text(value)
                .font(.title2.bold().monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .containerRelativeFrame(.horizontal, count: 3, span: 1, spacing: 12)
        .glassEffect(in: RoundedRectangle(cornerRadius: 16, style: .continuous))
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
        .glassEffect(in: Capsule())
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
