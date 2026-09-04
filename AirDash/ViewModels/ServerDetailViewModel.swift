import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class ServerDetailViewModel: ObservableObject {
    private static let lastDeviceNameKey = "lastUsedDeviceName"

    @Published var selectedProtocol: VPNProtocol = .wireguard
    @Published var selectedPort: Int? = nil
    @Published var selectedDevice: AirVPNDevice? = nil {
        didSet {
            guard let name = selectedDevice?.name else { return }
            UserDefaults.standard.set(name, forKey: Self.lastDeviceNameKey)
        }
    }
    @Published var devices: [AirVPNDevice] = []
    @Published var isLoadingDevices: Bool = false
    @Published var isGenerating: Bool = false
    @Published var errorMessage: String? = nil
    @Published var generatedProfile: GeneratedProfile? = nil
    @Published var showShareSheet: Bool = false
    @Published var showQRCode: Bool = false
    @Published var shareItems: [Any] = []
    @Published var generatedFileURL: URL? = nil
    @Published var isConnectingNative: Bool = false

    var availablePorts: [Int] { selectedProtocol.ports }

    func loadDevices(apiKey: String) async {
        isLoadingDevices = true
        do {
            let response = try await AirVPNAPIClient.shared.getDevices(apiKey: apiKey)
            devices = response.devices
            SharedDataService.writeDeviceNames(devices.map(\.name))
            // Auto-select the last used device if none selected, falling back to the first
            if selectedDevice == nil {
                let lastUsedName = UserDefaults.standard.string(forKey: Self.lastDeviceNameKey)
                selectedDevice = devices.first { $0.name == lastUsedName } ?? devices.first
            }
        } catch {
            // Non-fatal — user can still type a name
        }
        isLoadingDevices = false
    }

    func generateProfile(server: AirVPNServer, apiKey: String) async {
        isGenerating = true
        errorMessage = nil
        generatedProfile = nil

        do {
            let profile = try await AirVPNAPIClient.shared.generateProfile(
                apiKey: apiKey,
                protocol: selectedProtocol,
                serverName: server.publicName,
                port: selectedPort,
                deviceName: selectedDevice?.name
            )
            generatedProfile = profile
            prepareShare(profile: profile)
            ProfileHistoryService.shared.save(
                profile: profile,
                serverName: server.publicName,
                countryCode: server.countryCode,
                vpnProtocol: selectedProtocol,
                port: selectedPort,
                deviceName: selectedDevice?.name
            )
        } catch let error as AppError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
        isGenerating = false
    }

    private func prepareShare(profile: GeneratedProfile) {
        let tmpURL = FileManager.default.temporaryDirectory.appendingPathComponent(profile.filename)
        try? profile.content.write(to: tmpURL, atomically: true, encoding: .utf8)
        generatedFileURL = tmpURL
        shareItems = [tmpURL]
    }

    func importToVPNApp() {
        guard let url = generatedFileURL else { return }
        VPNProfileImporter.shared.presentOpenIn(url: url, vpnProtocol: selectedProtocol)
    }

    /// Connects the native tunnel using the profile already generated in this session —
    /// reuses `generatedProfile.content` as-is, no new API call, no key regeneration.
    func connectViaNativeTunnel(tunnelManager: VPNTunnelManager, serverName: String) async {
        guard let profile = generatedProfile, selectedProtocol == .wireguard else { return }
        isConnectingNative = true
        errorMessage = nil
        do {
            try await tunnelManager.saveTunnel(wgQuickConfigText: profile.content, serverName: serverName)
            try await tunnelManager.connect()
        } catch let error as AppError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
        isConnectingNative = false
    }

    /// Generates a profile and connects in one step, for the primary "Connect" action
    /// shown before generation — skips the intermediate "generated profile" screen
    /// entirely for people who just want to connect, not export a file.
    func connectDirectly(server: AirVPNServer, apiKey: String, tunnelManager: VPNTunnelManager) async {
        guard selectedProtocol == .wireguard else { return }
        isConnectingNative = true
        await generateProfile(server: server, apiKey: apiKey)
        guard generatedProfile != nil, errorMessage == nil else {
            isConnectingNative = false
            return
        }
        await connectViaNativeTunnel(tunnelManager: tunnelManager, serverName: server.publicName)
    }
}
