#if os(macOS)
import SwiftUI

struct SessionAnalyticsView: View {
    @ObservedObject var diagnostics: DiagnosticsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            currentConnection

            summaryCards

            if diagnostics.hasUnnamedWiFiUsage {
                unnamedWiFiNotice
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Usage by network")
                    .font(.title2.weight(.semibold))
                Text("How much data each network has used since this app was opened.")
                    .foregroundStyle(.secondary)
            }

            if diagnostics.sessionUsage.isEmpty {
                ContentUnavailableView(
                    "No usage counted yet",
                    systemImage: "chart.bar",
                    description: Text("Keep the app running and use the network. Totals will appear here automatically.")
                )
                .frame(maxWidth: .infinity, minHeight: 260)
            } else {
                Table(diagnostics.sessionUsage) {
                    TableColumn("Network") { row in
                        Text(row.networkName)
                            .fontWeight(.medium)
                    }
                    .width(min: 190, ideal: 240)

                    TableColumn("Connection") { row in
                        Text(row.connectionKind.rawValue)
                    }
                    .width(min: 90, ideal: 110)

                    TableColumn("Downloaded") { row in
                        Text(bytes(row.downloadedBytes))
                            .monospacedDigit()
                    }
                    .width(min: 110, ideal: 130)

                    TableColumn("Uploaded") { row in
                        Text(bytes(row.uploadedBytes))
                            .monospacedDigit()
                    }
                    .width(min: 100, ideal: 120)

                    TableColumn("Total used") { row in
                        Text(bytes(row.totalBytes))
                            .fontWeight(.semibold)
                            .monospacedDigit()
                    }
                    .width(min: 110, ideal: 130)

                    TableColumn("Share") { row in
                        Text(share(row.totalBytes))
                            .monospacedDigit()
                    }
                    .width(min: 70, ideal: 80)

                    TableColumn("Last active") { row in
                        Text(row.lastSeenAt, style: .time)
                            .monospacedDigit()
                    }
                    .width(min: 85, ideal: 95)
                }
                .frame(minHeight: 280)
            }

            Text("These totals currently last until the app is closed. Persistent Today, 7 days, 30 days and This month analytics will be enabled after measurement validation.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var currentConnection: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Connected now")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(diagnostics.currentNetworkName)
                    .font(.title3.weight(.semibold))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Divider()
                .frame(height: 40)

            liveMetric("Download now", diagnostics.totalDownloadBytesPerSecond)
            liveMetric("Upload now", diagnostics.totalUploadBytesPerSecond)
        }
        .padding(16)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 14))
    }

    private var summaryCards: some View {
        HStack(spacing: 12) {
            summaryCard("Total used", bytes(diagnostics.sessionTotalBytes), "Since app opened")
            summaryCard("Downloaded", bytes(diagnostics.sessionDownloadedBytes), "Received by this Mac")
            summaryCard("Uploaded", bytes(diagnostics.sessionUploadedBytes), "Sent by this Mac")
            summaryCard("Networks used", "\(diagnostics.sessionUsage.count)", "Separated by network identity")
        }
    }

    private var unnamedWiFiNotice: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "wifi.exclamationmark")
                .font(.title3)
            VStack(alignment: .leading, spacing: 3) {
                Text("Wi-Fi name unavailable")
                    .fontWeight(.semibold)
                Text("Traffic is being counted, but different Wi-Fi networks cannot be separated by name. Enable Wi-Fi identification in Settings to group future usage by Wi-Fi network.")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 12))
    }

    private func summaryCard(_ title: String, _ value: String, _ description: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title2.weight(.semibold))
                .monospacedDigit()
                .lineLimit(1)
            Text(description)
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
    }

    private func liveMetric(_ title: String, _ bytesPerSecond: Double) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(rate(bytesPerSecond))
                .font(.headline)
                .monospacedDigit()
        }
        .frame(minWidth: 130, alignment: .leading)
    }

    private func bytes(_ value: UInt64) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(clamping: value), countStyle: .decimal)
    }

    private func rate(_ bytesPerSecond: Double) -> String {
        let value = UInt64(max(0, bytesPerSecond.rounded()))
        return "\(bytes(value))/s"
    }

    private func share(_ bytes: UInt64) -> String {
        guard diagnostics.sessionTotalBytes > 0 else { return "0%" }
        let percentage = (Double(bytes) / Double(diagnostics.sessionTotalBytes)) * 100
        return percentage.formatted(.number.precision(.fractionLength(0))) + "%"
    }
}
#endif
