import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class ServerDetailViewModel: ObservableObject {
    @Published var selectedProtocol: VPNProtocol = .wireguard
    @Published var selectedPort: Int? = nil
    @Published var selectedDevice: AirVPNDevice? = nil
    @Published var devices: [AirVPNDevice] = []
    @Published var isLoadingDevices: Bool = false
    @Published var isGenerating: Bool = false
    @Published var errorMessage: String? = nil
    @Published var generatedProfile: GeneratedProfile? = nil
    @Published var showShareSheet: Bool = false
    @Published var showQRCode: Bool = false
    @Published var shareItems: [Any] = []
    @Published var generatedFileURL: URL? = nil

    var availablePorts: [Int] { selectedProtocol.ports }

    func loadDevices(apiKey: String) async {
        isLoadingDevices = true
        do {
            let response = try await AirVPNAPIClient.shared.getDevices(apiKey: apiKey)
            devices = response.devices
            // Auto-select first device if none selected
            if selectedDevice == nil {
                selectedDevice = devices.first
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
}
