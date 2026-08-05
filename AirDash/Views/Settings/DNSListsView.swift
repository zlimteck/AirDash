import SwiftUI

@MainActor
final class DNSListsViewModel: ObservableObject {
    @Published var lists: [AirVPNDNSList] = []
    @Published var isLoading = false
    @Published var errorMessage: String? = nil

    func load(forceRefresh: Bool = false) async {
        isLoading = true
        errorMessage = nil
        do {
            let response = try await AirVPNAPIClient.shared.getDNSLists(forceRefresh: forceRefresh)
            lists = response.sortedLists
        } catch let error as AppError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

struct DNSListsView: View {
    @StateObject private var vm = DNSListsViewModel()

    var body: some View {
        List {
            Section {
                Link(destination: URL(string: "https://airvpn.org/dns/")!) {
                    Label("dns.manage_on_website", systemImage: "safari")
                }
                .foregroundStyle(.primary)
            } footer: {
                Text("dns.manage_footer")
            }

            if let error = vm.errorMessage {
                Section {
                    ErrorBanner(message: error)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
            }

            Section {
                ForEach(vm.lists) { list in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(list.displayName)
                                .font(.subheadline.weight(.medium))
                            Spacer()
                            if let n = list.nItems {
                                Text("\(n)")
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                        }
                        if let description = list.description, !description.isEmpty {
                            Text(description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                    }
                    .padding(.vertical, 2)
                }
            } header: {
                Text(String(format: NSLocalizedString("dns.available_lists %lld", comment: ""), vm.lists.count))
            }
        }
        .navigationTitle("dns.title")
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if vm.isLoading && vm.lists.isEmpty {
                LoadingOverlay(label: "dns.loading")
            }
        }
        .task {
            await vm.load()
        }
        .refreshable {
            await vm.load(forceRefresh: true)
        }
    }
}
