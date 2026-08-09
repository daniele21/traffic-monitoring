#if os(macOS)
import AppKit
import SwiftUI

struct MenuBarView: View {
    @ObservedObject var diagnostics: DiagnosticsViewModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 11) {
                Image("BrandShield")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 42, height: 42)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Traffic Monitoring")
                        .font(.headline)
                    HStack(spacing: 6) {
                        Circle()
                            .fill(BrandTheme.signalCyan)
                            .frame(width: 6, height: 6)
                        Text(diagnostics.currentNetworkName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                Spacer()
            }

            Divider()

            HStack(spacing: 10) {
                compactMetric("Download", rate(diagnostics.totalDownloadBytesPerSecond), icon: "arrow.down", tint: BrandTheme.networkBlue)
                compactMetric("Upload", rate(diagnostics.totalUploadBytesPerSecond), icon: "arrow.up", tint: BrandTheme.signalCyan)
            }

            BrandCard(padding: 11) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Used since opening")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(bytes(diagnostics.sessionTotalBytes))
                            .font(.title3.weight(.semibold))
                            .monospacedDigit()
                    }
                    Spacer()
                    Image(systemName: "waveform.path.ecg")
                        .foregroundStyle(BrandTheme.signalCyan)
                }
            }

            Divider()

            Button {
                openWindow(id: "analytics")
                NSApp.activate(ignoringOtherApps: true)
            } label: {
                Label("Open Traffic Monitoring", systemImage: "rectangle.3.group")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .keyboardShortcut("o")

            Button {
                openWindow(id: "settings")
                NSApp.activate(ignoringOtherApps: true)
            } label: {
                Label("Settings", systemImage: "gearshape")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Divider()

            Button("Quit Traffic Monitoring") {
                diagnostics.stop()
                NSApp.terminate(nil)
            }
        }
        .padding(12)
        .frame(width: 320)
    }

    private func compactMetric(_ title: String, _ value: String, icon: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: icon)
                .font(.caption2)
                .foregroundStyle(tint)
            Text(value)
                .font(.callout.weight(.semibold))
                .monospacedDigit()
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(0.075), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
    }

    private func bytes(_ value: UInt64) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(clamping: value), countStyle: .decimal)
    }

    private func rate(_ bytesPerSecond: Double) -> String {
        "\(bytes(UInt64(max(0, bytesPerSecond.rounded()))))/s"
    }
}
#endif
