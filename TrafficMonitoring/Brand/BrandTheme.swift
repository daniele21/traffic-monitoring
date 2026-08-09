#if os(macOS)
import SwiftUI

enum BrandTheme {
    static let midnight = Color(red: 0.008, green: 0.051, blue: 0.173)
    static let deepNavy = Color(red: 0.055, green: 0.137, blue: 0.271)
    static let royalBlue = Color(red: 0.000, green: 0.161, blue: 0.588)
    static let networkBlue = Color(red: 0.125, green: 0.486, blue: 0.808)
    static let signalCyan = Color(red: 0.051, green: 0.757, blue: 0.976)

    static let healthy = Color(red: 0.133, green: 0.773, blue: 0.369)
    static let warning = Color(red: 0.961, green: 0.620, blue: 0.043)
    static let critical = Color(red: 0.937, green: 0.267, blue: 0.267)

    static let surfaceStroke = Color.secondary.opacity(0.12)
    static let chartSeries: [Color] = [
        royalBlue,
        signalCyan,
        Color(red: 0.36, green: 0.55, blue: 1.00),
        Color(red: 0.09, green: 0.65, blue: 0.65),
        Color(red: 0.42, green: 0.36, blue: 0.91),
        Color(red: 0.49, green: 0.55, blue: 0.64)
    ]

    static func statusColor(for state: AdvancedObservabilityProviderState) -> Color {
        switch state {
        case .active: healthy
        case .awaitingApproval: warning
        case .degraded: critical
        case .disabled, .providerUnavailable: .secondary
        }
    }

    static func evidenceColor(for quality: EvidenceQuality) -> Color {
        switch quality {
        case .identified: healthy
        case .partiallyIdentified: networkBlue
        case .unknownNetwork: warning
        case .trackingDegraded: critical
        }
    }
}

struct BrandProductHeader: View {
    let title: String
    let subtitle: String
    var compact = false

    var body: some View {
        HStack(spacing: compact ? 10 : 14) {
            Image("BrandShield")
                .resizable()
                .scaledToFit()
                .frame(width: compact ? 38 : 54, height: compact ? 38 : 54)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(compact ? .headline : .largeTitle.bold())
                Text(subtitle)
                    .font(compact ? .caption : .body)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
    }
}
#endif
