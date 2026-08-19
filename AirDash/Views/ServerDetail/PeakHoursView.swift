import SwiftUI
import Charts

private struct HourlyLoad: Identifiable {
    let hour: Int
    let averageLoad: Double
    var id: Int { hour }
}

struct PeakHoursView: View {
    let serverName: String

    @State private var hourlyLoads: [HourlyLoad] = []
    @State private var isLoading = false
    @State private var errorMessage: String? = nil

    private let chartHourLabel = String(localized: "peakhours.chart.hour")
    private let chartLoadLabel = String(localized: "peakhours.chart.load")

    private var quietestWindow: (start: Int, end: Int)? {
        guard hourlyLoads.count == 24 else { return nil }
        let loads = hourlyLoads.sorted { $0.hour < $1.hour }.map(\.averageLoad)
        var bestStart = 0
        var bestAverage = Double.greatestFiniteMagnitude
        for start in 0..<24 {
            let window = (0..<3).map { loads[(start + $0) % 24] }
            let average = window.reduce(0, +) / 3
            if average < bestAverage {
                bestAverage = average
                bestStart = start
            }
        }
        return (bestStart, (bestStart + 3) % 24)
    }

    var body: some View {
        Section {
            if isLoading && hourlyLoads.isEmpty {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .padding(.vertical, 24)
                .listRowSeparator(.hidden)
            } else if let errorMessage, hourlyLoads.isEmpty {
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
            } else if hourlyLoads.isEmpty {
                Text("history.no_data")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .listRowSeparator(.hidden)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    if let window = quietestWindow {
                        Label(
                            String(format: String(localized: "peakhours.quietest"), window.start, window.end),
                            systemImage: windowIcon(window)
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    Chart(hourlyLoads) { entry in
                        BarMark(
                            x: .value(chartHourLabel, entry.hour),
                            y: .value(chartLoadLabel, entry.averageLoad)
                        )
                        .foregroundStyle(barColor(entry.averageLoad))
                    }
                    .chartXAxis {
                        AxisMarks(values: [0, 6, 12, 18]) { value in
                            AxisGridLine()
                            AxisValueLabel {
                                if let hour = value.as(Int.self) {
                                    Text("\(hour)h")
                                }
                            }
                        }
                    }
                    .chartYScale(domain: 0...100)
                    .frame(height: 100)
                }
                .padding(.vertical, 8)
                .listRowSeparator(.hidden)
            }
        } header: {
            Label("peakhours.section", systemImage: "clock")
        }
        .task {
            await load()
        }
    }

    private func windowIcon(_ window: (start: Int, end: Int)) -> String {
        let midpoint = (window.start + 1) % 24
        return (6..<20).contains(midpoint) ? "sun.max.fill" : "moon.stars.fill"
    }

    private func barColor(_ load: Double) -> Color {
        switch load {
        case ..<50: .green
        case 50..<80: .orange
        default: .red
        }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            let response = try await AirVPNHistoryClient.shared.history(server: serverName, range: .sevenDays)
            let calendar = Calendar.current
            let grouped = Dictionary(grouping: response.points) { calendar.component(.hour, from: $0.date) }
            hourlyLoads = (0..<24).map { hour in
                let loads = grouped[hour]?.map(\.loadPercent) ?? []
                let average = loads.isEmpty ? 0 : loads.reduce(0, +) / Double(loads.count)
                return HourlyLoad(hour: hour, averageLoad: average)
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
}
