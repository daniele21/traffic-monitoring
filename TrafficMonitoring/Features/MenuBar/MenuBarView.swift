#if os(macOS)
import AppKit
import SwiftUI

struct MenuBarView: View {
    @ObservedObject var diagnostics: DiagnosticsViewModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(diagnostics.currentNetworkName)
                    .font(.headline)
                Text("Live interface usage")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()

            LabeledContent("Download") {
                Text(rate(diagnostics.totalDownloadBytesPerSecond))
                    .monospacedDigit()
            }
            LabeledContent("Upload") {
                Text(rate(diagnostics.totalUploadBytesPerSecond))
                    .monospacedDigit()
            }

            Divider()

            Button("Open Analytics") {
                openWindow(id: "analytics")
                NSApp.activate(ignoringOtherApps: true)
            }
            Button("Settings") {
                openWindow(id: "settings")
                NSApp.activate(ignoringOtherApps: true)
            }
            Divider()
            Button("Quit") { NSApp.terminate(nil) }
        }
        .padding(10)
        .frame(width: 260)
    }

    private func rate(_ bytesPerSecond: Double) -> String {
        let bytes = Int64(clamping: UInt64(max(0, bytesPerSecond.rounded())))
        return "\(ByteCountFormatter.string(fromByteCount: bytes, countStyle: .decimal))/s"
    }
}
#endif
