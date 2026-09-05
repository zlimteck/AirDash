import SwiftUI

/// Fetches PRIVACY.md (or PRIVACY.fr.md) straight from GitHub and renders it natively,
/// so the policy stays editable without shipping an app update, while still staying
/// inside the app instead of kicking the user out to Safari.
struct PrivacyPolicyView: View {
    @State private var lines: [String] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    private var rawURL: URL {
        let isFrench = Locale.current.language.languageCode?.identifier == "fr"
        let path = isFrench ? "PRIVACY.fr.md" : "PRIVACY.md"
        return URL(string: "https://raw.githubusercontent.com/zlimteck/AirDash/main/\(path)")!
    }

    var body: some View {
        Group {
            if isLoading {
                LoadingOverlay(label: "settings.privacy_policy")
            } else if let errorMessage {
                VStack(spacing: 12) {
                    ErrorBanner(message: errorMessage)
                    Button("history.retry") { Task { await load() } }
                }
                .padding()
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                            renderedLine(line)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .navigationTitle("settings.privacy_policy")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    @ViewBuilder
    private func renderedLine(_ line: String) -> some View {
        if line.hasPrefix("# ") {
            Text(LocalizedStringKey(String(line.dropFirst(2))))
                .font(.largeTitle.bold())
        } else if line.hasPrefix("## ") {
            Text(LocalizedStringKey(String(line.dropFirst(3))))
                .font(.title2.bold())
                .padding(.top, 8)
        } else if line.hasPrefix("- ") {
            HStack(alignment: .top, spacing: 6) {
                Text(verbatim: "•")
                Text(LocalizedStringKey(String(line.dropFirst(2))))
            }
        } else if line.isEmpty {
            Spacer().frame(height: 2)
        } else {
            Text(LocalizedStringKey(line))
        }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            let (data, _) = try await URLSession.shared.data(from: rawURL)
            guard let text = String(data: data, encoding: .utf8) else {
                throw URLError(.cannotDecodeContentData)
            }
            lines = text.components(separatedBy: "\n")
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
