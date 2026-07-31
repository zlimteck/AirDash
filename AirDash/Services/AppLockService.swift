import LocalAuthentication
import UIKit

@MainActor
final class AppLockService: ObservableObject {
    static let shared = AppLockService()

    @Published var isLocked = false

    private init() {
        if UserDefaults.standard.bool(forKey: "appLockEnabled") {
            isLocked = true
        }
        Task { @MainActor in
            for await _ in NotificationCenter.default.notifications(named: UIApplication.didEnterBackgroundNotification) {
                guard UserDefaults.standard.bool(forKey: "appLockEnabled") else { continue }
                self.lock()
            }
        }
    }

    func lock() {
        isLocked = true
    }

    func verifyBiometrics() async -> Bool {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            return true
        }
        let reason = String(localized: "lock.reason")
        return await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { result, _ in
                continuation.resume(returning: result)
            }
        }
    }

    func authenticate() async {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            isLocked = false
            return
        }
        let reason = String(localized: "lock.reason")
        let success = await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { result, _ in
                continuation.resume(returning: result)
            }
        }
        if success {
            isLocked = false
        }
    }
}
