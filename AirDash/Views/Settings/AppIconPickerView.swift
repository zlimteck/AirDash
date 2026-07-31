import SwiftUI

struct AppIconPickerView: View {
    @AppStorage("selectedAppIcon") private var selectedAppIcon: String = "Default"

    private let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 28) {
                ForEach(AppIconOption.allCases, id: \.self) { option in
                    AppIconCell(option: option, isSelected: selectedAppIcon == option.rawValue) {
                        setIcon(option)
                    }
                }
            }
            .padding()
        }
        .navigationTitle("settings.section.app_icon")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func setIcon(_ option: AppIconOption) {
        let iconName: String? = option == .default ? nil : option.rawValue
        UIApplication.shared.setAlternateIconName(iconName) { error in
            if error == nil {
                Task { @MainActor in
                    selectedAppIcon = option.rawValue
                }
            }
        }
    }
}

private struct AppIconCell: View {
    let option: AppIconOption
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack(alignment: .bottomTrailing) {
                    iconImage
                        .frame(width: 72, height: 72)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(isSelected ? Color.accentColor : Color.clear, lineWidth: 2.5)
                        )

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, Color.accentColor)
                            .font(.system(size: 18, weight: .semibold))
                            .offset(x: 4, y: 4)
                    }
                }
                Text(option.label)
                    .font(.caption)
                    .foregroundStyle(isSelected ? .primary : .secondary)
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
    }

    private var iconImage: some View {
        Image(option.previewImageName)
            .resizable()
            .scaledToFill()
    }
}
