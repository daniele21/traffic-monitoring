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
                Text("Connected now")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()

            LabeledContent("Download now") {
                Text(rate(diagnostics.totalDownloadBytesPerSecond))
                    .monospacedDigit()
            }
            LabeledContent("Upload now") {
                Text(rate(diagnostics.totalUploadBytesPerSecond))
                    .monospacedDigit()
            }
            LabeledContent("Used since opening") {
                Text(bytes(diagnostics.sessionTotalBytes))
                    .fontWeight(.semibold)
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
        .frame(width: 280)
    }

    private func bytes(_ value: UInt64) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(clamping: value), countStyle: .decimal)
    }

    private func rate(_ bytesPerSecond: Double) -> String {
        let value = UInt64(max(0, bytesPerSecond.rounded()))
        return "\(bytes(value))/s"
    }
}
#endif
