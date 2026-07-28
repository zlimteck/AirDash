import SwiftUI

@MainActor
final class DashboardViewModel: ObservableObject {
    @Published var userInfo: AirVPNUserInfoResponse? = nil
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    @Published var isDisconnecting: Bool = false
    @Published private var disconnectedIDs: Set<String> = []
    @Published var currentIP: String? = nil

    func load(apiKey: String, forceRefresh: Bool = false) async {
        isLoading = true
        errorMessage = nil
        async let userInfoTask = AirVPNAPIClient.shared.getUserInfo(apiKey: apiKey, forceRefresh: forceRefresh)
        async let ipTask = fetchPublicIP()
        do {
            userInfo = try await userInfoTask
        } catch is CancellationError {
        } catch let error as AppError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
        if let ip = await ipTask { currentIP = ip }
        isLoading = false
        SharedDataService.write(
            currentIP: currentIP,
            isVPNActive: isVPNActiveOnDevice,
            sessions: activeSessions,
            user: userInfo?.user
        )
    }

    private func fetchPublicIP() async -> String? {
        let candidates = [
            "https://api.ipify.org?format=json",
            "https://api4.my-ip.io/ip.json"
        ]
        struct IPResponse: Decodable { let ip: String }
        for urlString in candidates {
            guard let url = URL(string: urlString) else { continue }
            guard let (data, _) = try? await URLSession.shared.data(from: url) else { continue }
            if let result = try? JSONDecoder().decode(IPResponse.self, from: data) {
                return result.ip
            }
        }
        return nil
    }

    func disconnectSession(_ session: AirVPNSession, apiKey: String) async {
        isDisconnecting = true
        do {
            try await AirVPNAPIClient.shared.disconnectSession(
                apiKey: apiKey,
                ip: session.vpnIP,
                server: session.serverName,
                device: session.deviceName
            )
            // Hide immediately — don't wait for server propagation
            disconnectedIDs.insert(session.id)
            // Reload in background; clean optimistic filter once fresh data arrives
            try? await Task.sleep(for: .seconds(2))
            await load(apiKey: apiKey, forceRefresh: true)
            disconnectedIDs.remove(session.id)
        } catch is CancellationError {
            // ignore
        } catch let error as AppError {
            disconnectedIDs.remove(session.id)
            errorMessage = error.errorDescription
        } catch {
            disconnectedIDs.remove(session.id)
            errorMessage = error.localizedDescription
        }
        isDisconnecting = false
    }

    var activeSessions: [AirVPNSession] {
        let all = userInfo?.sessions ?? (userInfo?.connection.map { [$0] } ?? [])
        return all.filter { !disconnectedIDs.contains($0.id) }
    }

    var isVPNActiveOnDevice: Bool {
        guard let ip = currentIP else { return false }
        return activeSessions.contains { $0.exitIP == ip }
    }

    var expirationWarning: Bool {
        guard let days = userInfo?.user.expirationDays else { return false }
        return days < 30
    }
}
