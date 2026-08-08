#if os(macOS)
import SwiftUI

struct DashboardView: View {
    @ObservedObject var diagnostics: DiagnosticsViewModel
    let usageStore: LocalUsageStore
    @ObservedObject var advancedObservability: AdvancedObservabilityController
    @State private var section: DashboardSection = .analytics

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .bottom, spacing: 20) {
                BrandProductHeader(title: "Traffic Monitoring", subtitle: section.subtitle)
                Spacer()
                Picker("View", selection: $section) {
                    ForEach(visibleSections) { item in Text(item.rawValue).tag(item) }
                }
                .pickerStyle(.segmented)
                .frame(width: advancedObservability.isEnabled ? 390 : 270)
            }
            Divider()
            switch section {
            case .analytics: PersistentAnalyticsView(diagnostics: diagnostics, store: usageStore)
            case .applications: ApplicationsView(advanced: advancedObservability)
            case .monitor: monitorView
            }
        }
        .padding(24)
        .frame(minWidth: 1080, minHeight: 700)
        .onChange(of: advancedObservability.isEnabled) { _, enabled in
            if !enabled, section == .applications { section = .analytics }
        }
    }

    private var visibleSections: [DashboardSection] {
        var result: [DashboardSection] = [.analytics]
        if advancedObservability.isEnabled { result.append(.applications) }
        result.append(.monitor)
        return result
    }

    private var monitorView: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                metric("Current network", diagnostics.currentNetworkName)
                metric("Download now", rate(diagnostics.totalDownloadBytesPerSecond))
                metric("Upload now", rate(diagnostics.totalUploadBytesPerSecond))
            }
            Text("Technical interface view for validating how traffic is measured. Interface totals and 2-second changes are diagnostics, not usage by Wi-Fi network.")
                .font(.caption).foregroundStyle(.secondary)
            DiagnosticsView(viewModel: diagnostics).padding(-20)
        }
    }

    private func metric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.title3.weight(.semibold)).lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.quaternary.opacity(0.38), in: RoundedRectangle(cornerRadius: 12))
        .overlay { RoundedRectangle(cornerRadius: 12).stroke(BrandTheme.networkBlue.opacity(0.12), lineWidth: 1) }
    }

    private func rate(_ bytesPerSecond: Double) -> String {
        let bytes = Int64(clamping: UInt64(max(0, bytesPerSecond.rounded())))
        return "\(ByteCountFormatter.string(fromByteCount: bytes, countStyle: .decimal))/s"
    }
}

private enum DashboardSection: String, CaseIterable, Identifiable {
    case analytics = "Analytics"
    case applications = "Applications"
    case monitor = "Monitor"
    var id: String { rawValue }
    var subtitle: String {
        switch self {
        case .analytics: "Local history, trends, usage by network and evidence quality."
        case .applications: "Experimental app-level flow evidence with explicit unknown states."
        case .monitor: "Live technical view of the interfaces currently being measured."
        }
    }
}
#endif
