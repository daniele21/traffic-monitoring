#if os(macOS)
import SwiftUI

struct BrandCard<Content: View>: View {
    private let paddingAmount: CGFloat
    private let accent: Color?
    private let content: Content

    init(
        padding: CGFloat = 16,
        accent: Color? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.paddingAmount = padding
        self.accent = accent
        self.content = content()
    }

    var body: some View {
        content
            .padding(paddingAmount)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.background.opacity(0.72), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke((accent ?? BrandTheme.surfaceStroke), lineWidth: accent == nil ? 1 : 1.25)
            }
            .shadow(color: .black.opacity(0.035), radius: 8, y: 3)
    }
}

struct BrandMetricCard: View {
    let title: String
    let value: String
    let detail: String
    var icon: String? = nil
    var tint: Color = BrandTheme.networkBlue

    var body: some View {
        BrandCard {
            VStack(alignment: .leading, spacing: 9) {
                HStack(spacing: 7) {
                    if let icon {
                        Image(systemName: icon)
                            .foregroundStyle(tint)
                    }
                    Text(title)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                }

                Text(value)
                    .font(.system(size: 23, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(2)
            }
        }
    }
}

struct BrandStatusPill: View {
    let text: String
    var icon: String? = nil
    var tint: Color = BrandTheme.networkBlue

    var body: some View {
        HStack(spacing: 5) {
            if let icon {
                Image(systemName: icon)
            }
            Text(text)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(tint)
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(tint.opacity(0.11), in: Capsule())
        .overlay { Capsule().stroke(tint.opacity(0.16), lineWidth: 1) }
    }
}

struct BrandSectionHeader: View {
    let title: String
    let subtitle: String
    var icon: String? = nil

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            if let icon {
                Image(systemName: icon)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(BrandTheme.networkBlue)
                    .frame(width: 26, height: 26)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.title2.weight(.semibold))
                Text(subtitle)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
    }
}

struct BrandLiveIndicator: View {
    let label: String
    var tint: Color = BrandTheme.signalCyan

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(tint)
                .frame(width: 7, height: 7)
                .shadow(color: tint.opacity(0.45), radius: 4)
            Text(label)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
    }
}

struct BrandHeroSurface<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(
                    colors: [BrandTheme.midnight, BrandTheme.deepNavy, BrandTheme.royalBlue.opacity(0.88)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 20, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(.white.opacity(0.08), lineWidth: 1)
            }
            .shadow(color: BrandTheme.midnight.opacity(0.18), radius: 16, y: 6)
    }
}
#endif
