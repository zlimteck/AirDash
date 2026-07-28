import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var vm = OnboardingViewModel()
    @FocusState private var isKeyFocused: Bool

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [Color.accentColor.opacity(0.3), Color(.systemBackground)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 32) {
                    Spacer().frame(height: 60)

                    // Logo + Title
                    VStack(spacing: 12) {
                        Image(systemName: "shield.lefthalf.filled.badge.checkmark")
                            .font(.system(size: 72))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.tint)

                        Text("AirDash")
                            .font(.largeTitle.bold())

                        Text("onboarding.subtitle")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    // API Key input card
                    GlassCard {
                        VStack(alignment: .leading, spacing: 16) {
                            Label("onboarding.apikey.label", systemImage: "key.fill")
                                .font(.headline)

                            SecureField("onboarding.apikey.placeholder", text: $vm.apiKeyInput)
                                .textContentType(.password)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                                .focused($isKeyFocused)
                                .submitLabel(.go)
                                .onSubmit {
                                    guard !vm.apiKeyInput.isEmpty else { return }
                                    isKeyFocused = false
                                    Task { await vm.validate(appState: appState) }
                                }
                                .padding(12)
                                .background {
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(.quaternary)
                                }

                            if let error = vm.errorMessage {
                                Label(error, systemImage: "xmark.circle.fill")
                                    .font(.caption)
                                    .foregroundStyle(.red)
                            }
                        }
                    }
                    .padding(.horizontal)

                    // How to get API key
                    GlassCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("onboarding.howto.title", systemImage: "info.circle")
                                .font(.subheadline.bold())
                            Text("onboarding.howto.body")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal)

                    // Validate button
                    GlassButton("onboarding.validate", icon: "checkmark.shield") {
                        isKeyFocused = false
                        Task { await vm.validate(appState: appState) }
                    }
                    .padding(.horizontal)
                    .disabled(vm.isLoading || vm.apiKeyInput.isEmpty)
                    .overlay {
                        if vm.isLoading {
                            RoundedRectangle(cornerRadius: 14)
                                .fill(.ultraThinMaterial)
                                .overlay { ProgressView() }
                                .padding(.horizontal)
                        }
                    }

                    Spacer().frame(height: 40)
                }
            }
            .scrollDismissesKeyboard(.interactively)
        }
    }
}
