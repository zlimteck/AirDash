import SwiftUI

struct ServerDetailView: View {
    let server: AirVPNServer
    @EnvironmentObject var appState: AppState
    @StateObject private var vm = ServerDetailViewModel()

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // Server header card
                GlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 12) {
                            FlagBadge(countryCode: server.countryCode, size: 36)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(server.publicName)
                                    .font(.title2.bold())
                                Text(server.location)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            HealthDot(health: server.health)
                        }

                        Divider()

                        HStack(spacing: 20) {
                            StatItem(label: "detail.load", value: "\(Int(server.currentLoad))%")
                            StatItem(label: "detail.users", value: "\(server.users)")
                            StatItem(
                                label: "detail.bandwidth",
                                value: formatBandwidth(server.bw)
                            )
                        }

                        if let warning = server.warning, !warning.isEmpty {
                            Label(warning.trimmingCharacters(in: .init(charactersIn: "* ")), systemImage: "exclamationmark.triangle.fill")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                    }
                }
                .padding(.horizontal)

                // Profile generator
                GlassCard {
                    VStack(alignment: .leading, spacing: 16) {
                        Label("detail.generate_profile", systemImage: "doc.badge.plus")
                            .font(.headline)

                        // Protocol picker
                        Picker("detail.protocol", selection: $vm.selectedProtocol) {
                            ForEach(VPNProtocol.allCases, id: \.self) { proto in
                                Text(proto.displayName).tag(proto)
                            }
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: vm.selectedProtocol) { vm.selectedPort = nil }

                        // Port picker
                        HStack {
                            Text("detail.port")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Picker("detail.port", selection: $vm.selectedPort) {
                                Text("detail.default_port").tag(Optional<Int>.none)
                                ForEach(vm.availablePorts, id: \.self) { port in
                                    Text("\(port)").tag(Optional(port))
                                }
                            }
                            .tint(.secondary)
                        }

                        // Device picker
                        HStack {
                            Text("detail.device")
                                .foregroundStyle(.secondary)
                            Spacer()
                            if vm.isLoadingDevices {
                                ProgressView().scaleEffect(0.7)
                            } else if vm.devices.isEmpty {
                                Text("detail.no_devices")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else {
                                Picker("detail.device", selection: $vm.selectedDevice) {
                                    Text("detail.no_device").tag(Optional<AirVPNDevice>.none)
                                    ForEach(vm.devices) { device in
                                        Text(device.name).tag(Optional(device))
                                    }
                                }
                                .tint(.secondary)
                            }
                        }

                        if let error = vm.errorMessage {
                            Label(error, systemImage: "xmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.red)
                        }

                        if vm.generatedProfile == nil {
                            GlassButton(
                                "detail.generate",
                                icon: vm.isGenerating ? nil : "arrow.down.doc.fill"
                            ) {
                                Task { await vm.generateProfile(server: server, apiKey: appState.apiKey) }
                            }
                            .disabled(vm.isGenerating)
                            .overlay {
                                if vm.isGenerating {
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(.ultraThinMaterial)
                                        .overlay { ProgressView() }
                                }
                            }
                        } else {
                            // Post-generation actions
                            VStack(spacing: 10) {
                                GlassButton("detail.import_vpn", icon: "arrow.down.app.fill") {
                                    vm.importToVPNApp()
                                }

                                GlassButton("detail.share", icon: "square.and.arrow.up") {
                                    vm.showShareSheet = true
                                }

                                Button("detail.generate_new") {
                                    vm.generatedProfile = nil
                                    vm.generatedFileURL = nil
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .navigationTitle(server.publicName)
        .navigationBarTitleDisplayMode(.inline)
        .task { await vm.loadDevices(apiKey: appState.apiKey) }
        .sheet(isPresented: $vm.showShareSheet) {
            ShareSheet(items: vm.shareItems)
        }
    }

    private func formatBandwidth(_ bw: Double) -> String {
        if bw >= 1000 { return String(format: "%.0f Gbps", bw / 1000) }
        return String(format: "%.0f Mbps", bw)
    }
}

struct StatItem: View {
    let label: LocalizedStringKey
    let value: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.subheadline.bold().monospacedDigit())
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
