import SwiftUI

@main
struct AirDashApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .onAppear { appDelegate.appState = appState }
        }
    }
}
