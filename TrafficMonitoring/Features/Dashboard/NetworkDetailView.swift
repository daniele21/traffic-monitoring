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
        VStack(spacing: 0) {
            header
            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if let row {
                        metrics(row)
                        identityCard(row)
                        aliasCard(row)
                        trendCard
                    } else {
                        ContentUnavailableView("Network not found", systemImage: "network.slash")
                            .frame(maxWidth: .infinity, minHeight: 420)
                    }
                }
                .padding(22)
            }
        }
        .frame(width: 940, height: 700)
        .task { loadAlias() }
    }

    private var header: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(BrandTheme.networkBlue.opacity(0.11))
                    .frame(width: 50, height: 50)
                Image(systemName: row?.connectionKind == .wifi ? "wifi" : "network")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(BrandTheme.networkBlue)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(row?.networkName ?? "Network details")
                    .font(.title2.bold())
                Text("Usage, identity quality, and history for \(timeframe.rawValue.lowercased()).")
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if let row {
                BrandStatusPill(
                    text: analytics.identityQuality(for: row).title,
                    icon: identityIcon(for: row),
                    tint: BrandTheme.evidenceColor(for: analytics.identityQuality(for: row))
                )
            }

            Button("Done") { dismiss() }
                .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 16)
    }

    private func metrics(_ row: NetworkUsageHistoryRow) -> some View {
        HStack(spacing: 12) {
            BrandMetricCard(
                title: "Total used",
                value: bytes(row.totalBytes),
                detail: "Measured on this network",
                icon: "sum",
                tint: BrandTheme.networkBlue
            )
            BrandMetricCard(
                title: "Downloaded",
                value: bytes(row.downloadedBytes),
                detail: "Received by this Mac",
                icon: "arrow.down",
                tint: BrandTheme.networkBlue
            )
            BrandMetricCard(
                title: "Uploaded",
                value: bytes(row.uploadedBytes),
                detail: "Sent by this Mac",
                icon: "arrow.up",
                tint: BrandTheme.signalCyan
            )
            BrandMetricCard(
                title: timeframe.peakLabel,
                value: peak.map { bytes($0.totalBytes) } ?? "—",
                detail: peak.map { date($0.intervalStart) } ?? "No usage yet",
                icon: "bolt.fill",
                tint: BrandTheme.signalCyan
            )
        }
    }

    private func identityCard(_ row: NetworkUsageHistoryRow) -> some View {
        BrandCard {
            VStack(alignment: .leading, spacing: 14) {
                BrandSectionHeader(
                    title: "Network identity",
                    subtitle: "What Traffic Monitoring knows about this connection without inspecting packet contents.",
                    icon: "checkmark.shield"
                )

                HStack(spacing: 10) {
                    BrandStatusPill(
                        text: row.connectionKind.rawValue,
                        icon: row.connectionKind == .wifi ? "wifi" : "network",
                        tint: BrandTheme.networkBlue
                    )
                    BrandStatusPill(
                        text: analytics.identityQuality(for: row).title,
                        icon: identityIcon(for: row),
                        tint: BrandTheme.evidenceColor(for: analytics.identityQuality(for: row))
                    )
                    if row.isExpensive {
                        BrandStatusPill(
                            text: "Hotspot / expensive",
                            icon: "iphone.radiowaves.left.and.right",
                            tint: BrandTheme.signalCyan
                        )
                    }
                    if row.isConstrained {
                        BrandStatusPill(
                            text: "Constrained",
                            icon: "gauge.with.dots.needle.33percent",
                            tint: BrandTheme.warning
                        )
                    }
                    Spacer()
                }

                Divider()

                HStack(spacing: 36) {
                    info("First observed", date(row.firstSeenAt))
                    info("Last observed", date(row.lastSeenAt))
                    info("Technical identity", shortIdentity)
                    Spacer()
                }
            }
        }
    }

    private func aliasCard(_ row: NetworkUsageHistoryRow) -> some View {
        BrandCard {
            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Friendly name")
                        .font(.headline)
                    Text("Use a name such as Home, Office, or iPhone. The underlying network identity remains unchanged.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                TextField("Home, Office, iPhone…", text: $alias)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 220)

                Button("Save") { saveAlias() }

                if let saveMessage {
                    Text(saveMessage)
                        .font(.caption)
                        .foregroundStyle(saveMessage.hasPrefix("Could not") ? BrandTheme.critical : BrandTheme.healthy)
                        .frame(width: 110, alignment: .leading)
                }
            }
        }
    }

    private var trendCard: some View {
        BrandCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    BrandSectionHeader(
                        title: "Usage trend",
                        subtitle: "Traffic attributed to this network across the selected period.",
                        icon: "chart.xyaxis.line"
                    )
                    if let peak {
                        BrandStatusPill(
                            text: "Peak \(bytes(peak.totalBytes))",
                            icon: "bolt.fill",
                            tint: BrandTheme.signalCyan
                        )
                    }
                }

                if detailPoints.isEmpty {
                    ContentUnavailableView("No usage in this period", systemImage: "chart.bar")
                        .frame(minHeight: 250)
                } else {
                    Chart {
                        ForEach(detailPoints) { point in
                            LineMark(
                                x: .value("Time", point.intervalStart),
                                y: .value("Data used", Double(point.totalBytes))
                            )
                            .foregroundStyle(BrandTheme.networkBlue)
                            .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))

                            PointMark(
                                x: .value("Time", point.intervalStart),
                                y: .value("Data used", Double(point.totalBytes))
                            )
                            .foregroundStyle(point.id == peak?.id ? BrandTheme.signalCyan : BrandTheme.networkBlue.opacity(0.5))
                            .symbolSize(point.id == peak?.id ? 42 : 14)
                        }
                    }
                    .chartYAxis {
                        AxisMarks { value in
                            AxisGridLine().foregroundStyle(.secondary.opacity(0.12))
                            AxisValueLabel {
                                if let numeric = value.as(Double.self) {
                                    Text(bytes(UInt64(max(0, numeric))))
                                }
                            }
                        }
                    }
                    .frame(minHeight: 290)
                }
            }
        }
    }

    private var row: NetworkUsageHistoryRow? {
        analytics.detailRow(for: identityKey)
    }

    private var detailPoints: [UsageTrendPoint] {
        analytics.detailTrend(for: identityKey)
    }

    private var peak: UsageTrendPoint? {
        detailPoints.max { $0.totalBytes < $1.totalBytes }
    }

    private var shortIdentity: String {
        guard identityKey.count > 28 else { return identityKey }
        return String(identityKey.prefix(25)) + "…"
    }

    private func info(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.callout.weight(.medium))
                .lineLimit(1)
        }
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
            saveMessage = "Could not save"
        }
    }

    private func identityIcon(for row: NetworkUsageHistoryRow) -> String {
        switch analytics.identityQuality(for: row) {
        case .identified: "checkmark.seal.fill"
        case .partiallyIdentified: "info.circle.fill"
        case .unknownNetwork: "wifi.exclamationmark"
        case .trackingDegraded: "exclamationmark.triangle.fill"
        }
    }

    private func bytes(_ value: UInt64) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(clamping: value), countStyle: .decimal)
    }

    private func date(_ value: Date) -> String {
        value.formatted(.dateTime.day().month(.abbreviated).year().hour().minute())
    }
}
#endif
