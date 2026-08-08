#if os(macOS)
import Charts
import SwiftUI

struct PersistentAnalyticsView: View {
    @ObservedObject var diagnostics: DiagnosticsViewModel
    @StateObject private var analytics: HistoricalAnalyticsViewModel

    @State private var section: AnalyticsSection = .overview
    @State private var timeframe: AnalyticsTimeframe = .today
    @State private var selectedNetworkIdentity = Self.allNetworks
    @State private var customStart = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
    @State private var customEnd = Date()
    @State private var showAboutData = false
    @State private var showExport = false
    @State private var detailSelection: NetworkDetailSelection?

    private static let allNetworks = "__all_networks__"

    init(diagnostics: DiagnosticsViewModel, store: LocalUsageStore) {
        self.diagnostics = diagnostics
        _analytics = StateObject(wrappedValue: HistoricalAnalyticsViewModel(store: store))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            controls
            evidenceStatus

            if let error = analytics.errorMessage {
                Label(error, systemImage: "exclamationmark.triangle")
                    .font(.callout)
                    .foregroundStyle(.orange)
            }

            switch section {
            case .overview:
                overview
            case .trend:
                trend
            case .networks:
                networks
            }
        }
        .task {
            refresh()
            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: .seconds(15))
                } catch {
                    break
                }
                refresh()
            }
        }
        .onChange(of: timeframe) { _, _ in refresh() }
        .onChange(of: selectedNetworkIdentity) { _, _ in refresh() }
        .onChange(of: customStart) { _, _ in
            if timeframe == .custom { refresh() }
        }
        .onChange(of: customEnd) { _, _ in
            if timeframe == .custom { refresh() }
        }
        .sheet(isPresented: $showAboutData) {
            AboutThisDataView(coverage: analytics.coverageSummary)
        }
        .sheet(isPresented: $showExport) {
            EvidenceExportPreviewView(analytics: analytics)
        }
        .sheet(item: $detailSelection) { selection in
            NetworkDetailView(
                analytics: analytics,
                identityKey: selection.id,
                timeframe: timeframe,
                onChanged: { refresh() }
            )
        }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Picker("Analytics view", selection: $section) {
                    ForEach(AnalyticsSection.allCases) { item in
                        Text(item.rawValue).tag(item)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 320)

                Spacer()

                Button("About this data") {
                    showAboutData = true
                }

                Button("Export evidence…") {
                    showExport = true
                }

                Picker("Time period", selection: $timeframe) {
                    ForEach(AnalyticsTimeframe.allCases) { item in
                        Text(item.rawValue).tag(item)
                    }
                }
                .frame(width: 150)
            }

            if timeframe == .custom {
                HStack(spacing: 12) {
                    DatePicker("From", selection: $customStart, displayedComponents: .date)
                    DatePicker("To", selection: $customEnd, displayedComponents: .date)
                    Spacer()
                }
            }
        }
    }

    private var evidenceStatus: some View {
        HStack(spacing: 12) {
            Image(systemName: qualityIcon)
                .font(.title3)

            VStack(alignment: .leading, spacing: 2) {
                Text("Evidence quality · \(analytics.evidenceQuality.title)")
                    .fontWeight(.semibold)
                Text(analytics.evidenceQuality.explanation)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("Observed coverage")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(coveragePercentage)
                    .font(.headline)
                    .monospacedDigit()
            }

            if analytics.coverageSummary.unobservedSeconds > 1 {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Not observed")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(duration(analytics.coverageSummary.unobservedSeconds))
                        .font(.headline)
                        .monospacedDigit()
                }
            }
        }
        .padding(12)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 10))
    }

    private var overview: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                metricCard("Total used", bytes(analytics.overallSummary.totalBytes), "All measured network traffic")
                metricCard("Downloaded", bytes(analytics.overallSummary.downloadedBytes), "Received by this Mac")
                metricCard("Uploaded", bytes(analytics.overallSummary.uploadedBytes), "Sent by this Mac")
                metricCard("Networks used", "\(analytics.overallSummary.networkCount)", "Distinct detected networks")
            }

            storageStatus

            VStack(alignment: .leading, spacing: 4) {
                Text("Most used networks")
                    .font(.title2.weight(.semibold))
                Text("Networks ranked by total data used in the selected period.")
                    .foregroundStyle(.secondary)
            }

            if analytics.networkRows.isEmpty {
                emptyState
            } else {
                VStack(spacing: 10) {
                    ForEach(Array(analytics.networkRows.prefix(5))) { row in
                        networkRankRow(row)
                    }
                }
            }
        }
    }

    private var trend: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Usage trend")
                        .font(.title2.weight(.semibold))
                    Text("See when data usage increased and which network caused it.")
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Picker("Network", selection: $selectedNetworkIdentity) {
                    Text("All networks").tag(Self.allNetworks)
                    ForEach(analytics.networkRows) { row in
                        Text(row.networkName).tag(row.identityKey)
                    }
                }
                .frame(width: 220)
            }

            HStack(spacing: 12) {
                metricCard("Total used", bytes(analytics.trendSummary.totalBytes), selectedNetworkLabel)
                metricCard(
                    timeframe.peakLabel,
                    analytics.peakPoint.map { bytes($0.totalBytes) } ?? "—",
                    analytics.peakPoint.map { dateLabel($0.intervalStart) } ?? "No usage yet"
                )
                metricCard("Downloaded", bytes(analytics.trendSummary.downloadedBytes), selectedNetworkLabel)
                metricCard("Uploaded", bytes(analytics.trendSummary.uploadedBytes), selectedNetworkLabel)
            }

            if analytics.trendByNetwork.isEmpty {
                emptyState
            } else {
                Chart {
                    ForEach(analytics.trendByNetwork) { point in
                        BarMark(
                            x: .value("Time", point.intervalStart),
                            y: .value("Data used", Double(point.totalBytes))
                        )
                        .foregroundStyle(by: .value("Network", point.networkName))
                    }

                    if let peak = analytics.peakPoint {
                        RuleMark(x: .value("Peak", peak.intervalStart))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                            .foregroundStyle(.secondary)
                            .annotation(position: .top, alignment: .leading) {
                                Text("Peak · \(bytes(peak.totalBytes))")
                                    .font(.caption)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(.regularMaterial, in: Capsule())
                            }
                    }
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
                .chartLegend(position: .bottom, alignment: .leading)
                .frame(minHeight: 320)

                if let networkPeak = analytics.networkPeakPoint {
                    HStack(spacing: 8) {
                        Image(systemName: "bolt.fill")
                        Text("Largest network spike")
                            .fontWeight(.semibold)
                        Text("\(networkPeak.networkName) · \(bytes(networkPeak.totalBytes)) · \(dateLabel(networkPeak.intervalStart))")
                            .foregroundStyle(.secondary)
                    }
                    .font(.callout)
                }
            }
        }
    }

    private var networks: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Usage by network")
                    .font(.title2.weight(.semibold))
                Text("Compare usage and inspect how confidently each network was identified.")
                    .foregroundStyle(.secondary)
            }

            if analytics.networkRows.isEmpty {
                emptyState
            } else {
                Table(analytics.networkRows) {
                    TableColumn("Network") { row in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(row.networkName)
                                .fontWeight(.medium)
                            if row.isExpensive {
                                Text("Likely hotspot / expensive")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .width(min: 190, ideal: 230)

                    TableColumn("Evidence") { row in
                        Text(analytics.identityQuality(for: row).title)
                    }
                    .width(min: 115, ideal: 135)

                    TableColumn("Connection") { row in
                        Text(row.connectionKind.rawValue)
                    }
                    .width(min: 80, ideal: 100)

                    TableColumn("Downloaded") { row in
                        Text(bytes(row.downloadedBytes)).monospacedDigit()
                    }
                    .width(min: 100, ideal: 120)

                    TableColumn("Uploaded") { row in
                        Text(bytes(row.uploadedBytes)).monospacedDigit()
                    }
                    .width(min: 90, ideal: 110)

                    TableColumn("Total used") { row in
                        Text(bytes(row.totalBytes))
                            .fontWeight(.semibold)
                            .monospacedDigit()
                    }
                    .width(min: 100, ideal: 120)

                    TableColumn("Share") { row in
                        Text(share(row.totalBytes)).monospacedDigit()
                    }
                    .width(min: 60, ideal: 70)

                    TableColumn("Last active") { row in
                        Text(dateLabel(row.lastSeenAt))
                    }
                    .width(min: 110, ideal: 130)

                    TableColumn("") { row in
                        Button("Details") {
                            detailSelection = NetworkDetailSelection(id: row.identityKey)
                        }
                    }
                    .width(min: 70, ideal: 80)
                }
                .frame(minHeight: 340)
            }
        }
    }

    private var storageStatus: some View {
        HStack(spacing: 8) {
            Image(systemName: analytics.store.persistsAcrossRelaunches ? "externaldrive.fill.badge.checkmark" : "exclamationmark.triangle.fill")
            VStack(alignment: .leading, spacing: 2) {
                Text(analytics.store.persistsAcrossRelaunches ? "Saved locally" : "History is not being saved")
                    .fontWeight(.semibold)
                Text(
                    analytics.store.persistsAcrossRelaunches
                        ? "Usage and coverage evidence stay on this Mac in efficient 5-minute blocks, checkpointed about every 15 seconds."
                        : "The app is temporarily keeping usage only in memory."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(12)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 10))
    }

    private var emptyState: some View {
        ContentUnavailableView(
            "No usage in this period",
            systemImage: "chart.bar",
            description: Text("Keep Traffic Monitoring running while you use the network. Usage will appear automatically.")
        )
        .frame(maxWidth: .infinity, minHeight: 240)
    }

    private func networkRankRow(_ row: NetworkUsageHistoryRow) -> some View {
        HStack(spacing: 12) {
            Image(systemName: row.connectionKind == .wifi ? "wifi" : "network")
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text(row.networkName)
                    .fontWeight(.medium)
                Text("\(row.connectionKind.rawValue) · \(analytics.identityQuality(for: row).title)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(share(row.totalBytes))
                .foregroundStyle(.secondary)
                .monospacedDigit()

            Text(bytes(row.totalBytes))
                .fontWeight(.semibold)
                .monospacedDigit()
                .frame(width: 110, alignment: .trailing)

            Button("Details") {
                detailSelection = NetworkDetailSelection(id: row.identityKey)
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 4)
    }

    private func metricCard(_ title: String, _ value: String, _ description: String) -> some View {
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

    private var selectedNetworkLabel: String {
        guard selectedNetworkIdentity != Self.allNetworks else { return "All networks" }
        return analytics.networkRows.first { $0.identityKey == selectedNetworkIdentity }?.networkName ?? "Selected network"
    }

    private var coveragePercentage: String {
        (analytics.coverageSummary.observedRatio * 100)
            .formatted(.number.precision(.fractionLength(0))) + "%"
    }

    private var qualityIcon: String {
        switch analytics.evidenceQuality {
        case .identified: "checkmark.seal.fill"
        case .partiallyIdentified: "info.circle.fill"
        case .unknownNetwork: "wifi.exclamationmark"
        case .trackingDegraded: "exclamationmark.triangle.fill"
        }
    }

    private func refresh() {
        let selectedIdentity = selectedNetworkIdentity == Self.allNetworks ? nil : selectedNetworkIdentity
        analytics.refresh(
            timeframe: timeframe,
            customStart: customStart,
            customEnd: customEnd,
            selectedNetworkIdentity: selectedIdentity
        )

        if selectedNetworkIdentity != Self.allNetworks,
           !analytics.networkRows.contains(where: { $0.identityKey == selectedNetworkIdentity }) {
            selectedNetworkIdentity = Self.allNetworks
        }
    }

    private func bytes(_ value: UInt64) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(clamping: value), countStyle: .decimal)
    }

    private func share(_ value: UInt64) -> String {
        guard analytics.overallSummary.totalBytes > 0 else { return "0%" }
        let percentage = Double(value) / Double(analytics.overallSummary.totalBytes) * 100
        return percentage.formatted(.number.precision(.fractionLength(0))) + "%"
    }

    private func dateLabel(_ date: Date) -> String {
        switch timeframe.granularity {
        case .hour:
            return date.formatted(.dateTime.day().month(.abbreviated).hour().minute())
        case .day:
            return date.formatted(.dateTime.day().month(.abbreviated).year())
        }
    }

    private func duration(_ seconds: TimeInterval) -> String {
        let value = max(0, seconds)
        if value < 60 { return "\(Int(value.rounded())) sec" }
        if value < 3_600 { return "\(Int((value / 60).rounded())) min" }
        return (value / 3_600).formatted(.number.precision(.fractionLength(1))) + " hr"
    }
}

private enum AnalyticsSection: String, CaseIterable, Identifiable {
    case overview = "Overview"
    case trend = "Trend"
    case networks = "Networks"

    var id: Self { self }
}

private struct NetworkDetailSelection: Identifiable {
    let id: String
}
#endif
