#if os(macOS)
import Charts
import SwiftUI

struct PersistentAnalyticsView: View {
    @ObservedObject var diagnostics: DiagnosticsViewModel
    @StateObject private var analytics: HistoricalAnalyticsViewModel
    let section: AnalyticsSection

    @State private var timeframe: AnalyticsTimeframe = .today
    @State private var selectedNetworkIdentity = Self.allNetworks
    @State private var customStart = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
    @State private var customEnd = Date()
    @State private var showAboutData = false
    @State private var showExport = false
    @State private var detailSelection: NetworkDetailSelection?

    private static let allNetworks = "__all_networks__"

    init(diagnostics: DiagnosticsViewModel, store: LocalUsageStore, section: AnalyticsSection) {
        self.diagnostics = diagnostics
        self.section = section
        _analytics = StateObject(wrappedValue: HistoricalAnalyticsViewModel(store: store))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                controls

                if let error = analytics.errorMessage {
                    BrandCard(accent: BrandTheme.warning.opacity(0.45)) {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .font(.callout)
                            .foregroundStyle(BrandTheme.warning)
                    }
                }

                switch section {
                case .overview: overview
                case .trend: trend
                case .networks: networks
                }
            }
            .padding(.bottom, 12)
        }
        .task {
            refresh()
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(15)) } catch { break }
                refresh()
            }
        }
        .onChange(of: timeframe) { _, _ in refresh() }
        .onChange(of: selectedNetworkIdentity) { _, _ in refresh() }
        .onChange(of: customStart) { _, _ in if timeframe == .custom { refresh() } }
        .onChange(of: customEnd) { _, _ in if timeframe == .custom { refresh() } }
        .sheet(isPresented: $showAboutData) { AboutThisDataView(coverage: analytics.coverageSummary) }
        .sheet(isPresented: $showExport) { EvidenceExportPreviewView(analytics: analytics) }
        .sheet(item: $detailSelection) { selection in
            NetworkDetailView(
                analytics: analytics,
                identityKey: selection.id,
                timeframe: timeframe,
                onChanged: refresh
            )
        }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Label(timeframe.rawValue, systemImage: "calendar")
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.secondary)

                Picker("Period", selection: $timeframe) {
                    ForEach(AnalyticsTimeframe.allCases) { item in Text(item.rawValue).tag(item) }
                }
                .labelsHidden()
                .frame(width: 135)

                Spacer()

                Button { showAboutData = true } label: {
                    Label("About data", systemImage: "checkmark.shield")
                }
                Button { showExport = true } label: {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
            }

            if timeframe == .custom {
                BrandCard(padding: 12) {
                    HStack(spacing: 14) {
                        DatePicker("From", selection: $customStart, displayedComponents: .date)
                        DatePicker("To", selection: $customEnd, displayedComponents: .date)
                        Spacer()
                        Text("Custom ranges use daily aggregation.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - Overview

    private var overview: some View {
        VStack(alignment: .leading, spacing: 18) {
            overviewHero

            HStack(spacing: 12) {
                BrandMetricCard(title: "Downloaded", value: bytes(analytics.overallSummary.downloadedBytes), detail: "Received by this Mac", icon: "arrow.down", tint: BrandTheme.networkBlue)
                BrandMetricCard(title: "Uploaded", value: bytes(analytics.overallSummary.uploadedBytes), detail: "Sent by this Mac", icon: "arrow.up", tint: BrandTheme.signalCyan)
                BrandMetricCard(title: timeframe.peakLabel, value: analytics.peakPoint.map { bytes($0.totalBytes) } ?? "—", detail: analytics.peakPoint.map { dateLabel($0.intervalStart) } ?? "No usage yet", icon: "bolt.fill", tint: BrandTheme.signalCyan)
                BrandMetricCard(title: "Observed", value: coveragePercentage, detail: coverageDetail, icon: qualityIcon, tint: BrandTheme.evidenceColor(for: analytics.evidenceQuality))
            }

            evidenceStatus

            HStack(alignment: .top, spacing: 12) {
                topNetworkInsight
                localHistoryInsight
            }

            BrandSectionHeader(
                title: "Most used networks",
                subtitle: "Where the selected period's measured traffic happened.",
                icon: "wifi.router"
            )

            if topNetworkRows.isEmpty {
                emptyState
            } else {
                BrandCard {
                    VStack(spacing: 0) {
                        ForEach(topNetworkRows.indices, id: \.self) { index in
                            let row = topNetworkRows[index]
                            networkRankRow(row, rank: index + 1)
                            if index < topNetworkRows.count - 1 {
                                Divider().padding(.leading, 40)
                            }
                        }
                    }
                }
            }
        }
    }

    private var overviewHero: some View {
        BrandHeroSurface {
            HStack(alignment: .center, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(timeframe.rawValue.uppercased())
                        .font(.caption.weight(.bold))
                        .tracking(0.8)
                        .foregroundStyle(.white.opacity(0.68))
                    Text(bytes(analytics.overallSummary.totalBytes))
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                    Text("Total network usage · \(analytics.overallSummary.networkCount) network\(analytics.overallSummary.networkCount == 1 ? "" : "s")")
                        .font(.callout)
                        .foregroundStyle(.white.opacity(0.72))
                }

                Spacer()

                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 7) {
                        Circle().fill(BrandTheme.signalCyan).frame(width: 7, height: 7)
                        Text("LIVE").font(.caption2.bold()).tracking(0.7).foregroundStyle(BrandTheme.signalCyan)
                    }
                    Text(diagnostics.currentNetworkName)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    HStack(spacing: 18) {
                        liveRate("Download", diagnostics.totalDownloadBytesPerSecond, icon: "arrow.down")
                        liveRate("Upload", diagnostics.totalUploadBytesPerSecond, icon: "arrow.up")
                    }
                }
                .frame(minWidth: 280, alignment: .leading)
            }
        }
    }

    private func liveRate(_ label: String, _ value: Double, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Label(label, systemImage: icon).font(.caption2).foregroundStyle(.white.opacity(0.62))
            Text(rate(value)).font(.callout.weight(.semibold)).monospacedDigit().foregroundStyle(.white)
        }
    }

    private var topNetworkInsight: some View {
        BrandCard {
            VStack(alignment: .leading, spacing: 10) {
                Label("Top network", systemImage: "wifi")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(BrandTheme.networkBlue)
                if let row = analytics.networkRows.first {
                    Text(row.networkName).font(.title3.weight(.semibold))
                    Text(bytes(row.totalBytes)).font(.title2.bold()).monospacedDigit()
                    HStack(spacing: 8) {
                        BrandStatusPill(text: share(row.totalBytes), icon: "chart.pie", tint: BrandTheme.networkBlue)
                        if row.isExpensive { BrandStatusPill(text: "Hotspot", icon: "iphone.radiowaves.left.and.right", tint: BrandTheme.signalCyan) }
                    }
                } else {
                    Text("No network usage yet").foregroundStyle(.secondary)
                }
            }
        }
    }

    private var localHistoryInsight: some View {
        BrandCard {
            VStack(alignment: .leading, spacing: 10) {
                Label(
                    analytics.store.persistsAcrossRelaunches ? "Saved locally" : "History unavailable",
                    systemImage: analytics.store.persistsAcrossRelaunches ? "externaldrive.fill.badge.checkmark" : "exclamationmark.triangle.fill"
                )
                .font(.caption.weight(.semibold))
                .foregroundStyle(analytics.store.persistsAcrossRelaunches ? BrandTheme.healthy : BrandTheme.warning)

                Text(analytics.store.persistsAcrossRelaunches ? "Your history stays on this Mac." : "Usage is currently held only in memory.")
                    .font(.title3.weight(.semibold))
                Text(analytics.store.persistsAcrossRelaunches
                     ? "Traffic and coverage are stored in efficient 5-minute blocks with periodic checkpoints. No analytics backend is required."
                     : "Tracking continues, but historical analytics may not survive a relaunch until persistence recovers.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Trends

    private var trend: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .bottom) {
                BrandSectionHeader(title: "Usage over time", subtitle: "Understand peaks and isolate a network when needed.", icon: "chart.xyaxis.line")
                Picker("Network", selection: $selectedNetworkIdentity) {
                    Text("All networks").tag(Self.allNetworks)
                    ForEach(analytics.networkRows) { row in Text(row.networkName).tag(row.identityKey) }
                }
                .frame(width: 220)
            }

            HStack(spacing: 12) {
                BrandMetricCard(title: "Total used", value: bytes(analytics.trendSummary.totalBytes), detail: selectedNetworkLabel, icon: "sum", tint: BrandTheme.networkBlue)
                BrandMetricCard(title: timeframe.peakLabel, value: analytics.peakPoint.map { bytes($0.totalBytes) } ?? "—", detail: analytics.peakPoint.map { dateLabel($0.intervalStart) } ?? "No usage yet", icon: "bolt.fill", tint: BrandTheme.signalCyan)
                BrandMetricCard(title: "Downloaded", value: bytes(analytics.trendSummary.downloadedBytes), detail: selectedNetworkLabel, icon: "arrow.down", tint: BrandTheme.networkBlue)
                BrandMetricCard(title: "Uploaded", value: bytes(analytics.trendSummary.uploadedBytes), detail: selectedNetworkLabel, icon: "arrow.up", tint: BrandTheme.signalCyan)
            }

            BrandCard {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Traffic trend").font(.headline)
                            Text(selectedNetworkLabel).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if let peak = analytics.peakPoint {
                            BrandStatusPill(text: "Peak \(bytes(peak.totalBytes))", icon: "bolt.fill", tint: BrandTheme.signalCyan)
                        }
                    }

                    if analytics.totalTrend.isEmpty {
                        emptyState
                    } else {
                        Chart {
                            ForEach(analytics.totalTrend) { point in
                                LineMark(x: .value("Time", point.intervalStart), y: .value("Data used", Double(point.totalBytes)))
                                    .foregroundStyle(BrandTheme.networkBlue)
                                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                                PointMark(x: .value("Time", point.intervalStart), y: .value("Data used", Double(point.totalBytes)))
                                    .foregroundStyle(point.id == analytics.peakPoint?.id ? BrandTheme.signalCyan : BrandTheme.networkBlue.opacity(0.55))
                                    .symbolSize(point.id == analytics.peakPoint?.id ? 44 : 16)
                            }
                        }
                        .chartYAxis {
                            AxisMarks { value in
                                AxisGridLine().foregroundStyle(.secondary.opacity(0.12))
                                AxisValueLabel {
                                    if let numeric = value.as(Double.self) { Text(bytes(UInt64(max(0, numeric)))) }
                                }
                            }
                        }
                        .frame(minHeight: 330)
                    }
                }
            }

            if let networkPeak = analytics.networkPeakPoint {
                BrandCard(accent: BrandTheme.signalCyan.opacity(0.26)) {
                    Label("\(networkPeak.networkName) · \(bytes(networkPeak.totalBytes)) · \(dateLabel(networkPeak.intervalStart))", systemImage: "bolt.fill")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(BrandTheme.signalCyan)
                }
            }

            evidenceStatus
        }
    }

    // MARK: - Networks

    private var networks: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                BrandMetricCard(title: "Networks", value: "\(analytics.networkRows.count)", detail: "Seen in the selected period", icon: "wifi.router", tint: BrandTheme.networkBlue)
                BrandMetricCard(title: "Top network", value: analytics.networkRows.first.map { bytes($0.totalBytes) } ?? "—", detail: analytics.networkRows.first?.networkName ?? "No usage yet", icon: "chart.bar.fill", tint: BrandTheme.signalCyan)
                BrandMetricCard(title: "Hotspot-like", value: "\(analytics.networkRows.filter(\.isExpensive).count)", detail: "Marked expensive by macOS", icon: "iphone.radiowaves.left.and.right", tint: BrandTheme.signalCyan)
                BrandMetricCard(title: "Needs identification", value: "\(analytics.networkRows.filter { analytics.identityQuality(for: $0) != .identified }.count)", detail: "Partial or unknown identity", icon: "questionmark.circle", tint: BrandTheme.warning)
            }

            BrandSectionHeader(title: "Usage by network", subtitle: "Compare usage, connection type, evidence quality, and recency.", icon: "network")

            if analytics.networkRows.isEmpty {
                emptyState
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(analytics.networkRows) { row in networkCard(row) }
                }
            }

            evidenceStatus
        }
    }

    private func networkCard(_ row: NetworkUsageHistoryRow) -> some View {
        BrandCard {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(BrandTheme.networkBlue.opacity(0.1))
                        .frame(width: 46, height: 46)
                    Image(systemName: row.connectionKind == .wifi ? "wifi" : "network")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(BrandTheme.networkBlue)
                }

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 7) {
                        Text(row.networkName).font(.headline)
                        BrandStatusPill(text: analytics.identityQuality(for: row).title, tint: BrandTheme.evidenceColor(for: analytics.identityQuality(for: row)))
                        if row.isExpensive { BrandStatusPill(text: "Hotspot", icon: "iphone", tint: BrandTheme.signalCyan) }
                        if row.isConstrained { BrandStatusPill(text: "Constrained", icon: "gauge.with.dots.needle.33percent", tint: BrandTheme.warning) }
                    }
                    ProgressView(value: networkShareValue(row)).tint(BrandTheme.networkBlue).frame(maxWidth: 360)
                    Text("\(row.connectionKind.rawValue) · last active \(dateLabel(row.lastSeenAt))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(bytes(row.totalBytes)).font(.title3.weight(.semibold)).monospacedDigit()
                    Text("\(bytes(row.downloadedBytes)) down · \(bytes(row.uploadedBytes)) up")
                        .font(.caption).foregroundStyle(.secondary).monospacedDigit()
                }
                .frame(minWidth: 190, alignment: .trailing)

                Button("Details") { detailSelection = NetworkDetailSelection(id: row.identityKey) }
            }
        }
    }

    // MARK: - Shared cards

    private var evidenceStatus: some View {
        BrandCard(accent: BrandTheme.evidenceColor(for: analytics.evidenceQuality).opacity(0.32)) {
            HStack(spacing: 14) {
                Image(systemName: qualityIcon)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(BrandTheme.evidenceColor(for: analytics.evidenceQuality))
                    .frame(width: 30)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text("Data quality").font(.headline)
                        BrandStatusPill(text: analytics.evidenceQuality.title, tint: BrandTheme.evidenceColor(for: analytics.evidenceQuality))
                    }
                    Text(analytics.evidenceQuality.explanation).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                }
                Spacer()
                compactMetric("Observed", coveragePercentage)
                if analytics.coverageSummary.unobservedSeconds > 1 {
                    compactMetric("Not observed", duration(analytics.coverageSummary.unobservedSeconds))
                }
            }
        }
    }

    private func compactMetric(_ label: String, _ value: String) -> some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(label).font(.caption2).foregroundStyle(.secondary)
            Text(value).font(.callout.weight(.semibold)).monospacedDigit()
        }
        .frame(minWidth: 88, alignment: .trailing)
    }

    private func networkRankRow(_ row: NetworkUsageHistoryRow, rank: Int) -> some View {
        HStack(spacing: 12) {
            Text("\(rank)").font(.caption.bold()).foregroundStyle(.secondary).frame(width: 20)
            Image(systemName: row.connectionKind == .wifi ? "wifi" : "network").foregroundStyle(BrandTheme.networkBlue).frame(width: 20)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(row.networkName).fontWeight(.medium)
                    if row.isExpensive { BrandStatusPill(text: "Hotspot", tint: BrandTheme.signalCyan) }
                }
                Text("\(row.connectionKind.rawValue) · \(analytics.identityQuality(for: row).title)")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text(share(row.totalBytes)).font(.callout).foregroundStyle(.secondary).monospacedDigit()
            Text(bytes(row.totalBytes)).font(.callout.weight(.semibold)).monospacedDigit().frame(width: 108, alignment: .trailing)
            Button("Details") { detailSelection = NetworkDetailSelection(id: row.identityKey) }.buttonStyle(.borderless)
        }
        .padding(.vertical, 10)
    }

    private var emptyState: some View {
        ContentUnavailableView(
            "No usage in this period",
            systemImage: "chart.bar",
            description: Text("Keep Traffic Monitoring running while you use the network. Usage will appear automatically.")
        )
        .frame(maxWidth: .infinity, minHeight: 240)
    }

    // MARK: - Helpers

    private var topNetworkRows: [NetworkUsageHistoryRow] { Array(analytics.networkRows.prefix(5)) }

    private var selectedNetworkLabel: String {
        guard selectedNetworkIdentity != Self.allNetworks else { return "All networks" }
        return analytics.networkRows.first { $0.identityKey == selectedNetworkIdentity }?.networkName ?? "Selected network"
    }

    private var coveragePercentage: String {
        (analytics.coverageSummary.observedRatio * 100).formatted(.number.precision(.fractionLength(0))) + "%"
    }

    private var coverageDetail: String {
        analytics.coverageSummary.unobservedSeconds > 1
            ? "\(duration(analytics.coverageSummary.unobservedSeconds)) not observed"
            : "Selected period fully observed"
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
        analytics.refresh(timeframe: timeframe, customStart: customStart, customEnd: customEnd, selectedNetworkIdentity: selectedIdentity)
        if selectedNetworkIdentity != Self.allNetworks,
           !analytics.networkRows.contains(where: { $0.identityKey == selectedNetworkIdentity }) {
            selectedNetworkIdentity = Self.allNetworks
        }
    }

    private func bytes(_ value: UInt64) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(clamping: value), countStyle: .decimal)
    }

    private func rate(_ bytesPerSecond: Double) -> String { "\(bytes(UInt64(max(0, bytesPerSecond.rounded()))))/s" }

    private func share(_ value: UInt64) -> String {
        guard analytics.overallSummary.totalBytes > 0 else { return "0%" }
        return (Double(value) / Double(analytics.overallSummary.totalBytes) * 100).formatted(.number.precision(.fractionLength(0))) + "%"
    }

    private func networkShareValue(_ row: NetworkUsageHistoryRow) -> Double {
        guard analytics.overallSummary.totalBytes > 0 else { return 0 }
        return min(1, Double(row.totalBytes) / Double(analytics.overallSummary.totalBytes))
    }

    private func dateLabel(_ date: Date) -> String {
        switch timeframe.granularity {
        case .hour: date.formatted(.dateTime.day().month(.abbreviated).hour().minute())
        case .day: date.formatted(.dateTime.day().month(.abbreviated).year())
        }
    }

    private func duration(_ seconds: TimeInterval) -> String {
        let value = max(0, seconds)
        if value < 60 { return "\(Int(value.rounded())) sec" }
        if value < 3_600 { return "\(Int((value / 60).rounded())) min" }
        return (value / 3_600).formatted(.number.precision(.fractionLength(1))) + " hr"
    }
}

enum AnalyticsSection: String, CaseIterable, Identifiable {
    case overview = "Overview"
    case trend = "Trends"
    case networks = "Networks"
    var id: Self { self }
}

private struct NetworkDetailSelection: Identifiable { let id: String }
#endif
