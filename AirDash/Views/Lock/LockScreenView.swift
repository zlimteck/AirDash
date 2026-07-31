import LocalAuthentication
import SwiftUI

struct LockScreenView: View {
    @ObservedObject private var lockService = AppLockService.shared

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            VStack(spacing: 32) {
                VStack(spacing: 12) {
                    Image("IconPreview-Default")
                        .resizable()
                        .scaledToFill()
                        .frame(width: 84, height: 84)
                        .clipShape(RoundedRectangle(cornerRadius: 19, style: .continuous))
                        .shadow(color: .black.opacity(0.15), radius: 8, y: 4)

                    Text("AirDash")
                        .font(.title2.bold())
                }

                Button {
                    Task { await lockService.authenticate() }
                } label: {
                    Label("lock.unlock", systemImage: biometricIcon)
                        .font(.body.weight(.semibold))
                        .padding(.horizontal, 28)
                        .padding(.vertical, 14)
                        .background(Color.accentColor)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                }
            }
        }
        .task {
            await lockService.authenticate()
        }
    }

    private var biometricIcon: String {
        let context = LAContext()
        var error: NSError?
        context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
        return context.biometryType == .faceID ? "faceid" : "touchid"
    }
}
