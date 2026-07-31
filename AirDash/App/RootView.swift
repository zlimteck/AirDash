import SwiftUI

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
    }
}
