#if os(macOS)
import AppKit
import SwiftUI

struct MenuBarView: View {
    @ObservedObject var diagnostics: DiagnosticsViewModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image("BrandShield").resizable().scaledToFit().frame(width: 38, height: 38)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Traffic Monitoring").font(.headline)
                    Text(diagnostics.currentNetworkName).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            Divider()
            LabeledContent("Download now") { Text(rate(diagnostics.totalDownloadBytesPerSecond)).monospacedDigit() }
            LabeledContent("Upload now") { Text(rate(diagnostics.totalUploadBytesPerSecond)).monospacedDigit() }
            LabeledContent("Used since opening") { Text(bytes(diagnostics.sessionTotalBytes)).fontWeight(.semibold).monospacedDigit() }
            Divider()
            Button("Open Analytics") { openWindow(id: "analytics"); NSApp.activate(ignoringOtherApps: true) }
            Button("Settings") { openWindow(id: "settings"); NSApp.activate(ignoringOtherApps: true) }
            Divider()
            Button("Quit") { diagnostics.stop(); NSApp.terminate(nil) }
        }
        .padding(10)
        .frame(width: 300)
    }

    private func bytes(_ value: UInt64) -> String { ByteCountFormatter.string(fromByteCount: Int64(clamping: value), countStyle: .decimal) }
    private func rate(_ bytesPerSecond: Double) -> String { "\(bytes(UInt64(max(0, bytesPerSecond.rounded()))))/s" }
}
#endif
