import UIKit

// Holds a strong reference to the UIDocumentInteractionController for the
// duration of the presentation — releasing it early dismisses the menu.
@MainActor
final class VPNProfileImporter: NSObject, @preconcurrency UIDocumentInteractionControllerDelegate {
    static let shared = VPNProfileImporter()
    private override init() {}

    private var controller: UIDocumentInteractionController?

    func presentOpenIn(url: URL) {
        let dic = UIDocumentInteractionController(url: url)
        dic.delegate = self
        controller = dic

        guard
            let scene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive }),
            let root = scene.keyWindow?.rootViewController
        else { return }

        let presented = topViewController(from: root)
        let rect = CGRect(x: presented.view.bounds.midX, y: presented.view.bounds.midY, width: 0, height: 0)
        dic.presentOpenInMenu(from: rect, in: presented.view, animated: true)
    }

    func documentInteractionControllerDidDismissOpenInMenu(_ controller: UIDocumentInteractionController) {
        self.controller = nil
    }

    private func topViewController(from root: UIViewController) -> UIViewController {
        if let presented = root.presentedViewController {
            return topViewController(from: presented)
        }
        if let nav = root as? UINavigationController, let top = nav.topViewController {
            return topViewController(from: top)
        }
        if let tab = root as? UITabBarController, let selected = tab.selectedViewController {
            return topViewController(from: selected)
        }
        return root
    }
}
