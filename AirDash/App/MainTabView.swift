import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var appState: AppState
    @AppStorage("appTheme") private var appTheme: String = "system"

    private var colorScheme: ColorScheme? {
        switch appTheme {
        case "light": .light
        case "dark": .dark
        default: nil
        }
    }

    var body: some View {
        TabView(selection: $appState.selectedTab) {
            Tab("tab.network", systemImage: "globe", value: 0) {
                NetworkStatusView()
            }
            Tab("tab.dashboard", systemImage: "person.crop.circle", value: 1) {
                DashboardView()
            }
            Tab("tab.settings", systemImage: "gearshape", value: 2) {
                SettingsView()
            }
        }
        .preferredColorScheme(colorScheme)
    }
}
