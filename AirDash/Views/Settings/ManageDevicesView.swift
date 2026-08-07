import SwiftUI

@MainActor
final class ManageDevicesViewModel: ObservableObject {
    @Published var devices: [AirVPNDevice] = []
    @Published var isLoading = false
    @Published var errorMessage: String? = nil
    @Published var isMutating = false

    func load(apiKey: String, forceRefresh: Bool = false) async {
        isLoading = true
        errorMessage = nil
        do {
            let response = try await AirVPNAPIClient.shared.getDevices(apiKey: apiKey, forceRefresh: forceRefresh)
            devices = response.devices
            SharedDataService.writeDeviceNames(devices.map(\.name))
        } catch let error as AppError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func addDevice(apiKey: String, name: String, description: String) async -> Bool {
        isMutating = true
        errorMessage = nil
        do {
            let deviceId = try await AirVPNAPIClient.shared.addDevice(apiKey: apiKey, name: name, description: description)
            // The "add" action doesn't reliably persist name/description — set them explicitly.
            if !deviceId.isEmpty, !name.isEmpty {
                try await AirVPNAPIClient.shared.modifyDevice(apiKey: apiKey, deviceId: deviceId, name: name, description: description)
            }
            await load(apiKey: apiKey, forceRefresh: true)
            isMutating = false
            return true
        } catch let error as AppError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
        isMutating = false
        return false
    }

    func renewDevice(apiKey: String, deviceId: String) async {
        isMutating = true
        errorMessage = nil
        do {
            try await AirVPNAPIClient.shared.renewDevice(apiKey: apiKey, deviceId: deviceId)
            await load(apiKey: apiKey, forceRefresh: true)
        } catch let error as AppError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
        isMutating = false
    }

    func modifyDevice(apiKey: String, deviceId: String, name: String, description: String) async -> Bool {
        isMutating = true
        errorMessage = nil
        do {
            try await AirVPNAPIClient.shared.modifyDevice(apiKey: apiKey, deviceId: deviceId, name: name, description: description)
            await load(apiKey: apiKey, forceRefresh: true)
            isMutating = false
            return true
        } catch let error as AppError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
        isMutating = false
        return false
    }

    func deleteDevice(apiKey: String, deviceId: String) async {
        do {
            try await AirVPNAPIClient.shared.deleteDevice(apiKey: apiKey, deviceId: deviceId)
            devices.removeAll { $0.id == deviceId }
        } catch let error as AppError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct ManageDevicesView: View {
    static let maxDevices = 10

    @EnvironmentObject var appState: AppState
    @StateObject private var vm = ManageDevicesViewModel()
    @State private var showAddDevice = false
    @State private var devicePendingDeletion: AirVPNDevice? = nil

    var body: some View {
        List {
            if let error = vm.errorMessage {
                Section {
                    ErrorBanner(message: error)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
            }

            Section {
                ForEach(vm.devices) { device in
                    NavigationLink {
                        DeviceDetailView(device: device, vm: vm)
                            .environmentObject(appState)
                    } label: {
                        DeviceRowView(device: device)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            devicePendingDeletion = device
                        } label: {
                            Label("delete", systemImage: "trash")
                        }
                    }
                }
            } header: {
                Text(String(format: NSLocalizedString("devices.count %lld", comment: ""), vm.devices.count))
            } footer: {
                if vm.devices.count >= Self.maxDevices {
                    Text("devices.limit_reached")
                }
            }
        }
        .navigationTitle("devices.title")
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if vm.isLoading && vm.devices.isEmpty {
                LoadingOverlay(label: "devices.loading")
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showAddDevice = true
                } label: {
                    Image(systemName: "plus")
                }
                .disabled(vm.devices.count >= Self.maxDevices)
            }
        }
        .task {
            await vm.load(apiKey: appState.apiKey)
        }
        .refreshable {
            await vm.load(apiKey: appState.apiKey, forceRefresh: true)
        }
        .sheet(isPresented: $showAddDevice) {
            AddDeviceView(vm: vm)
                .environmentObject(appState)
        }
        .alert(
            "devices.remove_confirm",
            isPresented: Binding(
                get: { devicePendingDeletion != nil },
                set: { if !$0 { devicePendingDeletion = nil } }
            )
        ) {
            Button("delete", role: .destructive) {
                if let device = devicePendingDeletion {
                    Task { await vm.deleteDevice(apiKey: appState.apiKey, deviceId: device.id) }
                }
                devicePendingDeletion = nil
            }
            Button("cancel", role: .cancel) { devicePendingDeletion = nil }
        }
    }
}

struct DeviceRowView: View {
    let device: AirVPNDevice

    var lastSeenText: String {
        guard let unix = device.vpnLastFromUnix, unix > 0 else { return String(localized: "devices.never_connected") }
        return Date(timeIntervalSince1970: Double(unix)).relativeShortString
    }

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(device.status == "ready" ? Color.green : Color.secondary.opacity(0.4))
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(device.name)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                if let description = device.description, !description.isEmpty {
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                if let ip = device.wireguardIPv4 {
                    Text(ip)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Text(lastSeenText)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
        }
        .padding(.vertical, 2)
    }
}

struct AddDeviceView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var vm: ManageDevicesViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var description = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("devices.name_placeholder", text: $name)
                        .autocorrectionDisabled()
                    TextField("devices.description_placeholder", text: $description)
                } header: {
                    Text("devices.new_device")
                } footer: {
                    if let error = vm.errorMessage {
                        Label(error, systemImage: "xmark.circle.fill")
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("devices.add")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("settings.save") {
                        Task {
                            let ok = await vm.addDevice(apiKey: appState.apiKey, name: name, description: description)
                            if ok { dismiss() }
                        }
                    }
                    .disabled(vm.isMutating)
                    .overlay {
                        if vm.isMutating { ProgressView().scaleEffect(0.7) }
                    }
                }
            }
        }
    }
}

struct DeviceDetailView: View {
    let device: AirVPNDevice
    @ObservedObject var vm: ManageDevicesViewModel
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var description: String
    @State private var showRenewConfirm = false
    @State private var showDeleteConfirm = false

    init(device: AirVPNDevice, vm: ManageDevicesViewModel) {
        self.device = device
        self.vm = vm
        _name = State(initialValue: device.name)
        _description = State(initialValue: device.description ?? "")
    }

    var body: some View {
        Form {
            Section {
                TextField("devices.name_placeholder", text: $name)
                    .autocorrectionDisabled()
                TextField("devices.description_placeholder", text: $description)
            } header: {
                Text("devices.name_section")
            } footer: {
                if let error = vm.errorMessage {
                    Label(error, systemImage: "xmark.circle.fill")
                        .foregroundStyle(.red)
                }
            }

            Section {
                if let ip = device.wireguardIPv4 {
                    LabeledContent("IPv4", value: ip)
                }
                if let ip = device.wireguardIPv6 {
                    LabeledContent("IPv6", value: ip)
                }
            } header: {
                Text("devices.connection_info")
            }

            Section {
                Button {
                    showRenewConfirm = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 20, weight: .regular))
                            .foregroundStyle(.tint)
                            .frame(width: 26, alignment: .center)
                        Text("devices.renew")
                            .foregroundStyle(.primary)
                    }
                }
                .buttonStyle(.plain)
                .disabled(vm.isMutating)
            } footer: {
                Text("devices.renew_footer")
            }

            Section {
                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "trash")
                            .font(.system(size: 20, weight: .regular))
                            .foregroundStyle(.red)
                            .frame(width: 26, alignment: .center)
                        Text("delete")
                            .foregroundStyle(.red)
                    }
                }
                .disabled(vm.isMutating)
            }
        }
        .navigationTitle(device.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("settings.save") {
                    Task {
                        let ok = await vm.modifyDevice(apiKey: appState.apiKey, deviceId: device.id, name: name, description: description)
                        if ok { dismiss() }
                    }
                }
                .disabled(vm.isMutating || name.isEmpty)
            }
        }
        .alert("devices.renew_confirm", isPresented: $showRenewConfirm) {
            Button("devices.renew", role: .destructive) {
                Task { await vm.renewDevice(apiKey: appState.apiKey, deviceId: device.id) }
            }
            Button("cancel", role: .cancel) {}
        }
        .alert("devices.remove_confirm", isPresented: $showDeleteConfirm) {
            Button("delete", role: .destructive) {
                Task {
                    await vm.deleteDevice(apiKey: appState.apiKey, deviceId: device.id)
                    dismiss()
                }
            }
            Button("cancel", role: .cancel) {}
        }
    }
}
