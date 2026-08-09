import SwiftUI
import CoreSpotlight

struct RootView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject private var lockService = AppLockService.shared

    var body: some View {
        ZStack {
            if appState.isAuthenticated {
                MainTabView()
                    .transition(.opacity.combined(with: .scale(0.97)))
            } else {
                OnboardingView()
                    .transition(.opacity.combined(with: .scale(0.97)))
            }

            if lockService.isLocked && appState.isAuthenticated {
                LockScreenView()
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .onContinueUserActivity(CSSearchableItemActionType) { activity in
            guard let identifier = activity.userInfo?[CSSearchableItemActivityIdentifier] as? String else { return }
            handleSpotlightSelection(identifier)
        }
    }

    private func handleSpotlightSelection(_ identifier: String) {
        if identifier.hasPrefix(SpotlightItemID.serverPrefix) {
            let serverId = String(identifier.dropFirst(SpotlightItemID.serverPrefix.count))
            UserDefaults.standard.set(serverId, forKey: "pendingOpenServer")
            NotificationCenter.default.post(name: .openServer, object: serverId)
        } else if identifier.hasPrefix(SpotlightItemID.profilePrefix) {
            let profileIdString = String(identifier.dropFirst(SpotlightItemID.profilePrefix.count))
            if let uuid = UUID(uuidString: profileIdString),
               let entry = ProfileHistoryService.shared.entries.first(where: { $0.id == uuid }),
               entry.vpnProtocol == VPNProtocol.wireguard.rawValue {
                UserDefaults.standard.set(profileIdString, forKey: "pendingQRProfileId")
            }
            UserDefaults.standard.set(true, forKey: "pendingShowProfiles")
            NotificationCenter.default.post(name: .shortcutAction, object: 1)
            NotificationCenter.default.post(name: .showRecentProfiles, object: nil)
        }
    }
}
