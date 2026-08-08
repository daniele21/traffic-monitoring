#if os(macOS)
import SwiftUI

struct DashboardView: View {
    @ObservedObject var diagnostics: DiagnosticsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Network Usage")
                    .font(.largeTitle.bold())
                Text("M1 diagnostic build — historical analytics arrive after measurement validation.")
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                metric("Current network", diagnostics.currentNetworkName)
                metric("Download", rate(diagnostics.totalDownloadBytesPerSecond))
                metric("Upload", rate(diagnostics.totalUploadBytesPerSecond))
            }

            DiagnosticsView(viewModel: diagnostics)
                .padding(-20)
        }
        .padding(24)
        .frame(minWidth: 980, minHeight: 600)
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
#endif
