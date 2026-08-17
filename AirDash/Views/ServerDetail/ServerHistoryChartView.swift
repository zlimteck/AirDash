import SwiftUI
import Charts

struct ServerHistoryChartView: View {
    let serverName: String

    @State private var range: HistoryRange = .oneDay
    @State private var points: [ServerSnapshot] = []
    @State private var isLoading = false
    @State private var errorMessage: String? = nil

    private let chartTimeLabel = String(localized: "history.chart.time")
    private let chartLoadLabel = String(localized: "history.chart.load")
    private let chartUsersLabel = String(localized: "history.chart.users")

    var body: some View {
        Section {
            Picker("history.range", selection: $range) {
                ForEach(HistoryRange.allCases) { range in
                    Text(range.label).tag(range)
                }
            }
            .pickerStyle(.segmented)
            .listRowSeparator(.hidden)

            if isLoading && points.isEmpty {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .padding(.vertical, 24)
                .listRowSeparator(.hidden)
            } else if let errorMessage, points.isEmpty {
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
                .listRowSeparator(.hidden)
            } else if points.isEmpty {
                Text("history.no_data")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .listRowSeparator(.hidden)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("history.load")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Chart(points) { point in
                        LineMark(
                            x: .value(chartTimeLabel, point.date),
                            y: .value(chartLoadLabel, point.loadPercent)
                        )
                        .interpolationMethod(.monotone)
                        .foregroundStyle(.orange)
                        AreaMark(
                            x: .value(chartTimeLabel, point.date),
                            y: .value(chartLoadLabel, point.loadPercent)
                        )
                        .interpolationMethod(.monotone)
                        .foregroundStyle(.orange.opacity(0.12))
                    }
                    .chartYScale(domain: 0...100)
                    .frame(height: 140)
                }
                .padding(.vertical, 8)
                .listRowSeparator(.hidden)

                VStack(alignment: .leading, spacing: 8) {
                    Text("history.users")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Chart(points) { point in
                        LineMark(
                            x: .value(chartTimeLabel, point.date),
                            y: .value(chartUsersLabel, point.usersCount)
                        )
                        .interpolationMethod(.monotone)
                        .foregroundStyle(.blue)
                    }
                    .frame(height: 100)
                }
                .padding(.vertical, 8)
                .listRowSeparator(.hidden)

                if !healthPercentages.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("history.reliability")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        reliabilityBar
                        reliabilityLegend
                    }
                    .padding(.vertical, 8)
                    .listRowSeparator(.hidden)
                }
            }
        } header: {
            Label("history.section", systemImage: "chart.xyaxis.line")
        }
        .task(id: range) {
            await load()
        }
    }

    private var healthPercentages: [(AirVPNHealth, Double)] {
        let values = points.compactMap(\.health)
        guard !values.isEmpty else { return [] }
        let total = Double(values.count)
        return [AirVPNHealth.ok, .warning, .error].compactMap { health in
            let count = values.filter { $0 == health }.count
            guard count > 0 else { return nil }
            return (health, Double(count) / total * 100)
        }
    }

    private var reliabilityBar: some View {
        GeometryReader { geo in
            HStack(spacing: 2) {
                ForEach(healthPercentages, id: \.0.rawValue) { health, percent in
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(healthColor(health))
                        .frame(width: geo.size.width * (percent / 100))
                }
            }
        }
        .frame(height: 10)
    }

    private var reliabilityLegend: some View {
        HStack(spacing: 14) {
            ForEach(healthPercentages, id: \.0.rawValue) { health, percent in
                HStack(spacing: 4) {
                    Circle().fill(healthColor(health)).frame(width: 6, height: 6)
                    Text("\(healthLabel(health)) \(Int(percent.rounded()))%")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func healthColor(_ health: AirVPNHealth) -> Color {
        switch health {
        case .ok: .green
        case .warning: .orange
        case .error: .red
        }
    }

    private func healthLabel(_ health: AirVPNHealth) -> String {
        switch health {
        case .ok: String(localized: "history.reliability.ok")
        case .warning: String(localized: "history.reliability.warning")
        case .error: String(localized: "history.reliability.error")
        }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            let response = try await AirVPNHistoryClient.shared.history(server: serverName, range: range)
            points = response.points.sorted { $0.recordedAt < $1.recordedAt }
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
