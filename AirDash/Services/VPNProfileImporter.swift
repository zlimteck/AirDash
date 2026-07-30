import UIKit

// Holds a strong reference to the UIDocumentInteractionController for the
// duration of the presentation — releasing it early dismisses the menu.
@MainActor
final class VPNProfileImporter: NSObject, @preconcurrency UIDocumentInteractionControllerDelegate {
    static let shared = VPNProfileImporter()
    private override init() {}

    private var controller: UIDocumentInteractionController?

    private static let appStoreURLs: [VPNProtocol: URL] = [
        .wireguard: URL(string: "https://apps.apple.com/app/id1441195209")!,
        .openvpn:   URL(string: "https://apps.apple.com/app/id590379981")!
    ]

    func presentOpenIn(url: URL, vpnProtocol: VPNProtocol) {
        guard
            let scene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive }),
            let root = scene.keyWindow?.rootViewController
        else { return }

        let presented = topViewController(from: root)

        // For OpenVPN, canOpenURL("openvpn://") reliably detects installation.
        // presentOpenInMenu returns true even without the app (Files.app handles .ovpn),
        // so we bypass the menu entirely when the app is absent.
        if vpnProtocol == .openvpn,
           !UIApplication.shared.canOpenURL(URL(string: "openvpn://")!) {
            showAppStoreAlert(for: vpnProtocol, from: presented)
            return
        }

        let dic = UIDocumentInteractionController(url: url)
        dic.delegate = self
        controller = dic

        let rect = CGRect(x: presented.view.bounds.midX, y: presented.view.bounds.midY, width: 0, height: 0)
        let didShow = dic.presentOpenInMenu(from: rect, in: presented.view, animated: true)

        if !didShow {
            controller = nil
            showAppStoreAlert(for: vpnProtocol, from: presented)
        }
    }

    private func showAppStoreAlert(for vpnProtocol: VPNProtocol, from viewController: UIViewController) {
        let appName = vpnProtocol == .wireguard ? "WireGuard" : "OpenVPN Connect"
        let alert = UIAlertController(
            title: String(localized: LocalizedStringResource(stringLiteral: "import.app_missing.title")),
            message: String(format: String(localized: LocalizedStringResource(stringLiteral: "import.app_missing.message")), appName),
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(
            title: String(localized: LocalizedStringResource(stringLiteral: "import.app_missing.download")),
            style: .default
        ) { _ in
            if let storeURL = Self.appStoreURLs[vpnProtocol] {
                UIApplication.shared.open(storeURL)
            }
        })
        alert.addAction(UIAlertAction(
            title: String(localized: LocalizedStringResource(stringLiteral: "cancel")),
            style: .cancel
        ))
        viewController.present(alert, animated: true)
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
