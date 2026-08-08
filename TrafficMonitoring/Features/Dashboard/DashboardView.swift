#if os(macOS)
import SwiftUI

struct DashboardView: View {
    @ObservedObject var diagnostics: DiagnosticsViewModel
    @State private var section: DashboardSection = .analytics

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Network Usage")
                        .font(.largeTitle.bold())
                    Text(section.subtitle)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Picker("View", selection: $section) {
                    ForEach(DashboardSection.allCases) { item in
                        Text(item.rawValue).tag(item)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 240)
            }

            Divider()

            switch section {
            case .analytics:
                SessionAnalyticsView(diagnostics: diagnostics)
            case .monitor:
                monitorView
            }
        }
        .padding(24)
        .frame(minWidth: 980, minHeight: 640)
    }

    private var monitorView: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                metric("Connected now", diagnostics.currentNetworkName)
                metric("Download now", rate(diagnostics.totalDownloadBytesPerSecond))
                metric("Upload now", rate(diagnostics.totalUploadBytesPerSecond))
            }

            Text("Technical interface view for validating how traffic is measured. Raw counters and 2-second changes are not cumulative usage totals.")
                .font(.caption)
                .foregroundStyle(.secondary)

            DiagnosticsView(viewModel: diagnostics)
                .padding(-20)
        }
    }

    private func metric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.weight(.semibold))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
    }

    private func rate(_ bytesPerSecond: Double) -> String {
        let bytes = Int64(clamping: UInt64(max(0, bytesPerSecond.rounded())))
        return "\(ByteCountFormatter.string(fromByteCount: bytes, countStyle: .decimal))/s"
    }
}

private enum DashboardSection: String, CaseIterable, Identifiable {
    case analytics = "Analytics"
    case monitor = "Monitor"

    var id: String { rawValue }

    var subtitle: String {
        switch self {
        case .analytics:
            "See how much data this Mac has used and which networks used it."
        case .monitor:
            "Live technical view of the interfaces currently being measured."
        }
    }
}
#endif
