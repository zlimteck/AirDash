import SwiftUI

struct TrendsView: View {
    @State private var window: HistoryRange = .oneHour
    @State private var entries: [ServerRankingEntry] = []
    @State private var isLoading = false
    @State private var errorMessage: String? = nil

    var body: some View {
        List {
            Section {
                Picker("history.range", selection: $window) {
                    ForEach(HistoryRange.allCases) { window in
                        Text(window.label).tag(window)
                    }
                }
                .pickerStyle(.segmented)
                .listRowSeparator(.hidden)
            }
            .listRowBackground(Color.clear)

            if isLoading && entries.isEmpty {
                Section {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                    .padding(.vertical, 24)
                }
            } else if let errorMessage, entries.isEmpty {
                Section {
                    VStack(spacing: 8) {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        Button("history.retry") {
                            Task { await load() }
                        }
                        .font(.caption.weight(.semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                }
            } else if entries.isEmpty {
                Section {
                    Text("history.no_data")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
            } else {
                Section {
                    ForEach(entries) { entry in
                        TrendRankingRow(entry: entry)
                    }
                } header: {
                    Text("network.ranking")
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color(.systemGroupedBackground))
        .navigationTitle("network.trends")
        .navigationBarTitleDisplayMode(.large)
        .task(id: window) {
            await load()
        }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            let response = try await AirVPNHistoryClient.shared.ranking(window: window)
            entries = response.servers
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

private struct TrendRankingRow: View {
    let entry: ServerRankingEntry

    var body: some View {
        HStack(spacing: 12) {
            FlagBadge(countryCode: entry.countryCode ?? "", size: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.serverName)
                    .font(.headline)
                Text(entry.location ?? entry.countryName ?? "")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                LoadBar(load: entry.avgLoadPercent)
                    .frame(maxWidth: 120)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("\(Int(entry.avgLoadPercent.rounded()))%")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(loadColor(entry.avgLoadPercent))
                Text("\(entry.sampleCount) \(Text("trends.samples").foregroundStyle(.secondary))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private func loadColor(_ load: Double) -> Color {
        switch load {
        case ..<50: .green
        case 50..<80: .orange
        default: .red
        }
    }
}
