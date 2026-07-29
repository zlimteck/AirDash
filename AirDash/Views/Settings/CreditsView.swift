import SwiftUI

private struct CreditEntry: Identifiable, Sendable {
    let id = UUID()
    let name: String
    let role: String
    let url: URL?
}

private let credits: [CreditEntry] = [
    CreditEntry(
        name: "Aerya",
        role: "credits.aerya.role",
        url: URL(string: "https://github.com/Aerya/Gluetun-Companion")
    )
]

struct CreditsView: View {
    var body: some View {
        List {
            Section {
                ForEach(credits) { entry in
                    if let url = entry.url {
                        Link(destination: url) {
                            CreditRow(entry: entry)
                        }
                        .foregroundStyle(.primary)
                    } else {
                        CreditRow(entry: entry)
                    }
                }
            } header: {
                Text("credits.section.contributors")
            }
        }
        .navigationTitle("settings.credits")
        .navigationBarTitleDisplayMode(.large)
    }
}

private struct CreditRow: View {
    let entry: CreditEntry

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.name)
                    .font(.body)
                Text(LocalizedStringKey(entry.role))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if entry.url != nil {
                Image(systemName: "arrow.up.right")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
            }
        }
    }
}
