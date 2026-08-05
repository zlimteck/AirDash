import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var vm = OnboardingViewModel()
    @FocusState private var isKeyFocused: Bool

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [Color.accentColor.opacity(0.3), Color(.systemGroupedBackground)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
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
                    VStack(alignment: .leading, spacing: 14) {
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

                        if let error = vm.errorMessage {
                            Label(error, systemImage: "xmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                    .padding(16)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .padding(.horizontal)

                    // How to get API key
                    VStack(alignment: .leading, spacing: 8) {
                        Label("onboarding.howto.title", systemImage: "info.circle")
                            .font(.subheadline.bold())
                        Text("onboarding.howto.body")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .padding(.horizontal)

                    // Validate button
                    Button {
                        isKeyFocused = false
                        Task { await vm.validate(appState: appState) }
                    } label: {
                        if vm.isLoading {
                            ProgressView().frame(maxWidth: .infinity)
                        } else {
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.shield")
                                Text("onboarding.validate")
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                    .disabled(vm.isLoading || vm.apiKeyInput.isEmpty)
                    .padding(.horizontal)

                    Spacer().frame(height: 40)
                }
            }
            .scrollDismissesKeyboard(.interactively)
        }
    }
}
