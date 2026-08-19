import SwiftUI
import Charts

struct ComparisonHistoryView: View {
    let servers: [AirVPNServer]

    @State private var range: HistoryRange = .oneDay
    @State private var seriesByServer: [String: [ServerSnapshot]] = [:]
    @State private var isLoading = false
    @State private var errorMessage: String? = nil

    private let chartTimeLabel = String(localized: "history.chart.time")
    private let chartLoadLabel = String(localized: "history.chart.load")
    private let chartServerLabel = String(localized: "comparison.chart.server")

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("comparison.history", systemImage: "chart.xyaxis.line")
                .font(.subheadline.bold())

            Picker("history.range", selection: $range) {
                ForEach(HistoryRange.allCases) { range in
                    Text(range.label).tag(range)
                }
            }
            .pickerStyle(.segmented)

            if isLoading && seriesByServer.isEmpty {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .padding(.vertical, 20)
            } else if let errorMessage, seriesByServer.isEmpty {
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
            } else if seriesByServer.isEmpty {
                Text("history.no_data")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            } else {
                Chart {
                    ForEach(servers) { server in
                        if let points = seriesByServer[server.publicName] {
                            ForEach(points) { point in
                                LineMark(
                                    x: .value(chartTimeLabel, point.date),
                                    y: .value(chartLoadLabel, point.loadPercent)
                                )
                                .foregroundStyle(by: .value(chartServerLabel, server.publicName))
                                .interpolationMethod(.monotone)
                            }
                        }
                    }
                }
                .chartYScale(domain: 0...100)
                .chartLegend(position: .bottom, spacing: 8)
                .frame(height: 160)
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .task(id: range) {
            await load()
        }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        var newSeries: [String: [ServerSnapshot]] = [:]
        await withTaskGroup(of: (String, [ServerSnapshot]?).self) { group in
            for server in servers {
                let name = server.publicName
                group.addTask {
                    let result = try? await AirVPNHistoryClient.shared.history(server: name, range: range)
                    return (name, result?.points.sorted { $0.recordedAt < $1.recordedAt })
                }
            }
            for await (name, points) in group {
                if let points, !points.isEmpty { newSeries[name] = points }
            }
        }
        seriesByServer = newSeries
        if newSeries.isEmpty {
            errorMessage = String(localized: "error.upstream_unavailable")
        }
        isLoading = false
    }
}
