import SwiftUI

@MainActor
final class OnboardingViewModel: ObservableObject {
    @Published var apiKeyInput: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil

    func validate(appState: AppState) async {
        let key = apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else {
            errorMessage = String(localized: "onboarding.error.empty_key")
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let response = try await AirVPNAPIClient.shared.validateAPIKey(key)
            appState.signIn(with: key, login: response.user.login)
        } catch let error as AppError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}
