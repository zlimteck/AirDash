import SwiftUI

struct ServerDetailView: View {
    let server: AirVPNServer
    @EnvironmentObject var appState: AppState
    @StateObject private var vm = ServerDetailViewModel()

    var body: some View {
        List {
            // Server header
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        FlagBadge(countryCode: server.countryCode, size: 36)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(server.publicName)
                                .font(.title2.bold())
                            HStack(spacing: 6) {
                                Text(server.location)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                if server.ipV6In1 != nil {
                                    Text("IPv6")
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(.blue)
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 2)
                                        .background(Capsule().fill(.blue.opacity(0.15)))
                                }
                            }
                        }
                        Spacer()
                        HealthDot(health: server.health)
                    }
                    Divider()
                    HStack(spacing: 20) {
                        StatItem(label: "detail.load", value: "\(Int(server.currentLoad))%")
                        StatItem(label: "detail.users", value: "\(server.users)")
                        StatItem(label: "detail.bandwidth", value: formatBandwidth(server.bw))
                    }
                    if let warning = server.warning, !warning.isEmpty {
                        Label(warning.trimmingCharacters(in: .init(charactersIn: "* ")), systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
                .listRowInsets(EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16))
                .listRowSeparator(.hidden)
            }

            // IP addresses
            Section {
                if let ip = server.ipV4In1 { CopyableIPRow(label: "IPv4 (1)", ip: ip) }
                if let ip = server.ipV4In2 { CopyableIPRow(label: "IPv4 (2)", ip: ip) }
                if let ip = server.ipV6In1 { CopyableIPRow(label: "IPv6", ip: ip) }
            } header: {
                Label("detail.ip_addresses", systemImage: "network")
            }

            // Profile generator — pickers
            if vm.generatedProfile == nil {
                Section {
                    Picker("detail.protocol", selection: $vm.selectedProtocol) {
                        ForEach(VPNProtocol.allCases, id: \.self) { proto in
                            Text(proto.displayName).tag(proto)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: vm.selectedProtocol) { vm.selectedPort = nil }
                    .listRowSeparator(.hidden)

                    Picker("detail.port", selection: $vm.selectedPort) {
                        Text("detail.default_port").tag(Optional<Int>.none)
                        ForEach(vm.availablePorts, id: \.self) { port in
                            Text("\(port)").tag(Optional(port))
                        }
                    }

                    if vm.isLoadingDevices {
                        HStack {
                            Text("detail.device").foregroundStyle(.secondary)
                            Spacer()
                            ProgressView().scaleEffect(0.8)
                        }
                    } else if vm.devices.isEmpty {
                        HStack {
                            Text("detail.device").foregroundStyle(.secondary)
                            Spacer()
                            Text("detail.no_devices").font(.caption).foregroundStyle(.secondary)
                        }
                    } else {
                        Picker("detail.device", selection: $vm.selectedDevice) {
                            Text("detail.no_device").tag(Optional<AirVPNDevice>.none)
                            ForEach(vm.devices) { device in
                                Text(device.name).tag(Optional(device))
                            }
                        }
                    }

                    if let error = vm.errorMessage {
                        Label(error, systemImage: "xmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.red)
                            .listRowSeparator(.hidden)
                    }

                    Button {
                        Task { await vm.generateProfile(server: server, apiKey: appState.apiKey) }
                    } label: {
                        if vm.isGenerating {
                            ProgressView().frame(maxWidth: .infinity)
                        } else {
                            Label("detail.generate", systemImage: "arrow.down.doc.fill")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                    .disabled(vm.isGenerating)
                    .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                    .listRowSeparator(.hidden)

                } header: {
                    Label("detail.generate_profile", systemImage: "doc.badge.plus")
                }
            } else {
                // Post-generation actions
                Section {
                    Button {
                        vm.importToVPNApp()
                    } label: {
                        Label("detail.import_vpn", systemImage: "arrow.down.app.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                    .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                    .listRowSeparator(.hidden)

                    Button {
                        vm.showShareSheet = true
                    } label: {
                        Label("detail.share", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                    .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                    .listRowSeparator(.hidden)

                    Button("detail.generate_new") {
                        vm.generatedProfile = nil
                        vm.generatedFileURL = nil
                    }
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .listRowSeparator(.hidden)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color(.systemGroupedBackground))
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

struct CopyableIPRow: View {
    let label: String
    let ip: String
    @State private var copied = false

    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 70, alignment: .leading)
            Text(ip)
                .font(.caption.monospaced())
                .foregroundStyle(copied ? .green : .primary)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
            if copied {
                Image(systemName: "checkmark")
                    .font(.caption2)
                    .foregroundStyle(.green)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.2), value: copied)
        .contextMenu {
            Button { copyIP() } label: {
                Label("copy", systemImage: "doc.on.doc")
            }
        }
    }

    private func copyIP() {
        UIPasteboard.general.string = ip
        withAnimation { copied = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { copied = false }
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
