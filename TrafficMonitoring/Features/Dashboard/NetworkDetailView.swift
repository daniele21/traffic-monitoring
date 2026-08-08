#if os(macOS)
import Charts
import SwiftUI

struct NetworkDetailView: View {
    @ObservedObject var analytics: HistoricalAnalyticsViewModel
    let identityKey: String
    let timeframe: AnalyticsTimeframe
    let onChanged: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var alias = ""
    @State private var saveMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(row?.networkName ?? "Network details")
                        .font(.title2.bold())
                    Text("Observed usage and identity quality for the selected period.")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Close") { dismiss() }
            }

            if let row {
                HStack(spacing: 12) {
                    metric("Total used", bytes(row.totalBytes))
                    metric("Downloaded", bytes(row.downloadedBytes))
                    metric("Uploaded", bytes(row.uploadedBytes))
                    metric("Identity", analytics.identityQuality(for: row).title)
                }

                HStack(spacing: 14) {
                    Label(row.connectionKind.rawValue, systemImage: row.connectionKind == .wifi ? "wifi" : "network")
                    Text("First observed: \(date(row.firstSeenAt))")
                    Text("Last observed: \(date(row.lastSeenAt))")
                    if row.isExpensive {
                        Label("Likely hotspot / expensive", systemImage: "iphone.radiowaves.left.and.right")
                    }
                }
                .font(.callout)
                .foregroundStyle(.secondary)

                GroupBox("Display name") {
                    HStack {
                        TextField("Friendly name, e.g. Home or iPhone", text: $alias)
                            .textFieldStyle(.roundedBorder)
                        Button("Save alias") { saveAlias() }
                        if let saveMessage {
                            Text(saveMessage)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Usage trend")
                        .font(.headline)

                    let points = analytics.detailTrend(for: identityKey)
                    if points.isEmpty {
                        ContentUnavailableView("No usage in this period", systemImage: "chart.bar")
                            .frame(minHeight: 220)
                    } else {
                        Chart(points) { point in
                            BarMark(
                                x: .value("Time", point.intervalStart),
                                y: .value("Data used", Double(point.totalBytes))
                            )
                        }
                        .chartYAxis {
                            AxisMarks { value in
                                AxisGridLine()
                                AxisValueLabel {
                                    if let numeric = value.as(Double.self) {
                                        Text(bytes(UInt64(max(0, numeric))))
                                    }
                                }
                            }
                        }
                        .frame(minHeight: 260)
                    }
                }
            } else {
                ContentUnavailableView("Network not found", systemImage: "network.slash")
            }

            Spacer()
        }
        .padding(22)
        .frame(width: 820, height: 650)
        .task { loadAlias() }
    }

    private var row: NetworkUsageHistoryRow? {
        analytics.detailRow(for: identityKey)
    }

    private func loadAlias() {
        alias = (try? analytics.alias(for: identityKey)) ?? ""
    }

    private func saveAlias() {
        do {
            try analytics.renameNetwork(identityKey: identityKey, alias: alias)
            saveMessage = alias.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Alias removed" : "Alias saved"
            onChanged()
        } catch {
            saveMessage = "Could not save: \(error.localizedDescription)"
        }
    }

    private func metric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.weight(.semibold))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 10))
    }

    private func bytes(_ value: UInt64) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(clamping: value), countStyle: .decimal)
    }

    private func date(_ value: Date) -> String {
        value.formatted(.dateTime.day().month(.abbreviated).year().hour().minute())
    }
}
#endif
