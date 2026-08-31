import SwiftUI

@main
struct AirDashApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            #if VPN_ENABLED
            RootView()
                .environmentObject(appState)
                .environmentObject(VPNTunnelManager.shared)
            #else
            RootView()
                .environmentObject(appState)
            #endif
        }
    }
}
