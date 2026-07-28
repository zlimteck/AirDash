import UIKit

final class AppDelegate: NSObject, UIApplicationDelegate {
    var appState: AppState?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        application.shortcutItems = Self.staticShortcuts
        return true
    }

    func application(
        _ application: UIApplication,
        performActionFor shortcutItem: UIApplicationShortcutItem,
        completionHandler: @escaping (Bool) -> Void
    ) {
        completionHandler(handle(shortcutItem))
    }

    @discardableResult
    func handle(_ item: UIApplicationShortcutItem) -> Bool {
        switch item.type {
        case ShortcutType.dashboard:
            appState?.selectedTab = 1
        case ShortcutType.network:
            appState?.selectedTab = 0
        default:
            return false
        }
        return true
    }

    static let staticShortcuts: [UIApplicationShortcutItem] = [
        UIApplicationShortcutItem(
            type: ShortcutType.dashboard,
            localizedTitle: NSLocalizedString("tab.dashboard", comment: ""),
            localizedSubtitle: nil,
            icon: UIApplicationShortcutIcon(systemImageName: "person.crop.circle"),
            userInfo: nil
        ),
        UIApplicationShortcutItem(
            type: ShortcutType.network,
            localizedTitle: NSLocalizedString("tab.network", comment: ""),
            localizedSubtitle: nil,
            icon: UIApplicationShortcutIcon(systemImageName: "globe"),
            userInfo: nil
        )
    ]
}

enum ShortcutType {
    static let dashboard = "com.airdash.ios.dashboard"
    static let network   = "com.airdash.ios.network"
}
