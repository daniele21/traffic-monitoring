#if os(macOS)
import SwiftUI

struct AboutThisDataView: View {
    let coverage: EvidenceCoverageSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("About this data")
                .font(.title2.bold())

            Label(coverage.quality.title, systemImage: qualityIcon)
                .font(.headline)

            Text(coverage.quality.explanation)
                .foregroundStyle(.secondary)

            Grid(alignment: .leading, horizontalSpacing: 22, verticalSpacing: 10) {
                row("Selected period", duration(coverage.selectedSeconds))
                row("Observed", duration(coverage.observedSeconds))
                row("Healthy observation", duration(coverage.healthySeconds))
                row("Not observed", duration(coverage.unobservedSeconds))
                row("Wi-Fi / metadata degraded", duration(coverage.metadataDegradedSeconds))
                row("Tracking degraded", duration(coverage.trackingDegradedSeconds))
            }

            Divider()

            Text("What Traffic Monitoring measures")
                .font(.headline)
            Text("Traffic Monitoring measures bytes on physical network interfaces and associates them with the network context observed by macOS. It does not inspect packet contents, websites, messages, DNS history, or browsing content.")
                .foregroundStyle(.secondary)

            Text("What these totals do not prove")
                .font(.headline)
            Text("Network-interface usage can include local-network traffic. These totals are not exact ISP or mobile-carrier billing data, and the current core does not identify which application generated traffic or whether a flow reached the public Internet.")
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding(22)
        .frame(width: 560, height: 500)
    }

    @ViewBuilder
    private func row(_ label: String, _ value: String) -> some View {
        GridRow {
            Text(label)
                .foregroundStyle(.secondary)
            Text(value)
                .monospacedDigit()
        }
    }

    private var qualityIcon: String {
        switch coverage.quality {
        case .identified: "checkmark.seal.fill"
        case .partiallyIdentified: "info.circle.fill"
        case .unknownNetwork: "wifi.exclamationmark"
        case .trackingDegraded: "exclamationmark.triangle.fill"
        }
    }

    private func duration(_ seconds: TimeInterval) -> String {
        let value = max(0, seconds)
        if value < 60 { return "\(Int(value.rounded())) sec" }
        if value < 3_600 { return "\(Int((value / 60).rounded())) min" }
        return (value / 3_600).formatted(.number.precision(.fractionLength(1))) + " hr"
    }
}
#endif
