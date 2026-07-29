import UIKit

final class SceneDelegate: NSObject, UIWindowSceneDelegate {
    func windowScene(
        _ windowScene: UIWindowScene,
        performActionFor shortcutItem: UIApplicationShortcutItem,
        completionHandler: @escaping (Bool) -> Void
    ) {
        let tab: Int
        switch shortcutItem.type {
        case ShortcutType.dashboard: tab = 1
        case ShortcutType.network:   tab = 0
        default:
            completionHandler(false)
            return
        }
        NotificationCenter.default.post(name: .shortcutAction, object: tab)
        completionHandler(true)
    }
}
