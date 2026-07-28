import SwiftUI
import FlagKit

struct GlassCard<Content: View>: View {
    let content: Content
    var padding: CGFloat = 16

    init(padding: CGFloat = 16, @ViewBuilder content: () -> Content) {
        self.content = content()
        self.padding = padding
    }

    var body: some View {
        content
            .padding(padding)
            .glassEffect(in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

struct GlassButton: View {
    let title: LocalizedStringKey
    let icon: String?
    let role: ButtonRole?
    let action: () -> Void

    init(_ title: LocalizedStringKey, icon: String? = nil, role: ButtonRole? = nil, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.role = role
        self.action = action
    }

    var body: some View {
        Button(role: role, action: action) {
            Group {
                if let icon {
                    Label(title, systemImage: icon)
                } else {
                    Text(title)
                }
            }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
        }
        .glassEffect(in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .foregroundStyle(role == .destructive ? .red : .primary)
    }
}

// Health indicator dot
struct HealthDot: View {
    let health: AirVPNHealth

    var color: Color {
        switch health {
        case .ok: .green
        case .warning: .orange
        case .error: .red
        }
    }

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 8, height: 8)
            .shadow(color: color.opacity(0.6), radius: 3)
    }
}

// Load bar
struct LoadBar: View {
    let load: Double // 0..100

    var color: Color {
        switch load {
        case ..<50: .green
        case 50..<80: .orange
        default: .red
        }
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(.quaternary)
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(color.gradient)
                    .frame(width: geo.size.width * min(load / 100, 1.0))
            }
        }
        .frame(height: 6)
    }
}

// MARK: - Flag Badge

struct FlagBadge: View {
    let countryCode: String
    var size: CGFloat = 36

    var body: some View {
        Group {
            if let flag = Flag(countryCode: countryCode.uppercased()) {
                Image(uiImage: flag.image(style: .roundedRect))
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                // fallback: country code text
                Text(countryCode.uppercased())
                    .font(.system(size: size * 0.3, weight: .bold, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.secondary.opacity(0.15))
            }
        }
        .frame(width: size, height: size * 0.72)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: size * 0.14, style: .continuous)
                .strokeBorder(.primary.opacity(0.1), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.12), radius: 2, x: 0, y: 1)
    }
}

// Kept as free function for backwards-compat in code that only needs the string
func countryFlag(_ countryCode: String) -> String {
    let base: UInt32 = 127397
    return countryCode.uppercased().unicodeScalars.compactMap { scalar in
        Unicode.Scalar(scalar.value + base).map(String.init)
    }.joined()
}

// MARK: - Status Pill

struct StatusPill: View {
    let isActive: Bool
    let label: LocalizedStringKey

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(isActive ? Color.green : Color.secondary)
                .frame(width: 7, height: 7)
                .shadow(color: isActive ? .green.opacity(0.5) : .clear, radius: 3)
            Text(label)
                .font(.caption.weight(.medium))
                .foregroundStyle(isActive ? .primary : .secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule().fill(isActive ? Color.green.opacity(0.12) : Color.secondary.opacity(0.1))
        )
    }
}

// MARK: - Premium Badge

struct PremiumBadge: View {
    let isPremium: Bool

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: isPremium ? "checkmark.seal.fill" : "seal")
                .font(.caption)
                .foregroundStyle(isPremium ? Color.yellow : .secondary)
            Text(isPremium ? "dashboard.premium" : "dashboard.standard")
                .font(.caption.weight(.medium))
                .foregroundStyle(isPremium ? Color(red: 0.7, green: 0.55, blue: 0) : .secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule().fill(isPremium ? Color.yellow.opacity(0.12) : Color.secondary.opacity(0.08))
        )
    }
}
