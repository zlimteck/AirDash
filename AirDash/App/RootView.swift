import SwiftUI

struct RootView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        if appState.isAuthenticated {
            MainTabView()
                .transition(.opacity.combined(with: .scale(0.97)))
        } else {
            OnboardingView()
                .transition(.opacity.combined(with: .scale(0.97)))
        }
    }
}
