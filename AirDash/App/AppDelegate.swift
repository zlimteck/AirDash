import UIKit

extension Notification.Name {
    static let shortcutAction = Notification.Name("com.airdash.shortcutAction")
}

final class AppDelegate: NSObject, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        application.shortcutItems = Self.staticShortcuts
        return true
    }

    // Lancement froid depuis une Quick Action — shortcut dans les options de connexion
    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        if let shortcut = options.shortcutItem {
            let tab: Int = shortcut.type == ShortcutType.network ? 0 : 1
            UserDefaults.standard.set(tab, forKey: "pendingShortcutTab")
        }
        let config = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        config.delegateClass = SceneDelegate.self
        return config
    }

    // Fallback si le scene delegate ne traite pas l'action
    func application(
        _ application: UIApplication,
        performActionFor shortcutItem: UIApplicationShortcutItem,
        completionHandler: @escaping (Bool) -> Void
    ) {
        let tab: Int
        switch shortcutItem.type {
        case ShortcutType.dashboard: tab = 1
        case ShortcutType.network:   tab = 0
        default: completionHandler(false); return
        }
        NotificationCenter.default.post(name: .shortcutAction, object: tab)
        completionHandler(true)
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
