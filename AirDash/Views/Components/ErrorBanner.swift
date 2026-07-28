import SwiftUI

struct ErrorBanner: View {
    let message: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.primary)
            Spacer()
        }
        .padding(12)
        .glassEffect(in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .padding(.horizontal)
    }
}

struct LoadingOverlay: View {
    var label: LocalizedStringKey = "loading"

    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(32)
        .glassEffect(in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}
