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

    static func statusColor(for state: AdvancedObservabilityProviderState) -> Color {
        switch state {
        case .active: healthy
        case .awaitingApproval: warning
        case .degraded: critical
        case .disabled, .providerUnavailable: .secondary
        }
    }
}

struct BrandProductHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 14) {
            Image("BrandShield")
                .resizable()
                .scaledToFit()
                .frame(width: 54, height: 54)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.largeTitle.bold())
                Text(subtitle)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
#endif
