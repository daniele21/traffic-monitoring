#if os(macOS)
import SwiftUI

struct DashboardView: View {
    @ObservedObject var diagnostics: DiagnosticsViewModel
    let usageStore: LocalUsageStore
    @ObservedObject var advancedObservability: AdvancedObservabilityController
    @ObservedObject var lightweightAppActivity: LightweightAppActivityController

    @State private var destination: DashboardDestination = .overview
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 220, ideal: 245, max: 280)
        } detail: {
            detail
        }
        .navigationSplitViewStyle(.balanced)
        .frame(minWidth: 1120, minHeight: 720)
    }

    private var sidebar: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 16) {
                BrandProductHeader(title: "Traffic Monitoring", subtitle: "Local network observability", compact: true)
                Divider()
            }
            .padding(.horizontal, 16)
            .padding(.top, 18)
            .padding(.bottom, 10)

            List(selection: $destination) {
                Section("Analytics") {
                    sidebarRow(.overview)
                    sidebarRow(.trends)
                    sidebarRow(.networks)
                }
                Section("Evidence") {
                    sidebarRow(.applications)
                    sidebarRow(.monitor)
                }
            }
            .listStyle(.sidebar)

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: networkIcon)
                        .foregroundStyle(BrandTheme.signalCyan)
                        .frame(width: 20)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Current network").font(.caption2).foregroundStyle(.secondary)
                        Text(diagnostics.currentNetworkName).font(.caption.weight(.semibold)).lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }

                HStack(spacing: 12) {
                    Label(rate(diagnostics.totalDownloadBytesPerSecond), systemImage: "arrow.down")
                    Label(rate(diagnostics.totalUploadBytesPerSecond), systemImage: "arrow.up")
                }
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)

                Button {
                    openWindow(id: "settings")
                } label: {
                    Label("Settings", systemImage: "gearshape")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
            .padding(16)
        }
        .background(.thinMaterial)
    }

    @ViewBuilder
    private func sidebarRow(_ item: DashboardDestination) -> some View {
        HStack(spacing: 9) {
            Label(item.title, systemImage: item.icon)
            Spacer(minLength: 4)
            if item == .applications {
                Text("BETA")
                    .font(.system(size: 8, weight: .bold, design: .rounded))
                    .foregroundStyle(BrandTheme.signalCyan)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(BrandTheme.signalCyan.opacity(0.1), in: Capsule())
            }
        }
        .tag(item)
    }

    private var detail: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 14) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(destination.title).font(.largeTitle.bold())
                    Text(destination.subtitle).foregroundStyle(.secondary)
                }
                Spacer()
                BrandLiveIndicator(label: "Tracking live")
            }
            .padding(.horizontal, 26)
            .padding(.top, 22)
            .padding(.bottom, 16)

            Divider()

            Group {
                switch destination {
                case .overview:
                    PersistentAnalyticsView(diagnostics: diagnostics, store: usageStore, section: .overview)
                case .trends:
                    PersistentAnalyticsView(diagnostics: diagnostics, store: usageStore, section: .trend)
                case .networks:
                    PersistentAnalyticsView(diagnostics: diagnostics, store: usageStore, section: .networks)
                case .applications:
                    ApplicationsView(advanced: advancedObservability, lightweight: lightweightAppActivity)
                case .monitor:
                    monitorView
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .background(Color.primary.opacity(0.018))
    }

    private var monitorView: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                BrandMetricCard(title: "Current network", value: diagnostics.currentNetworkName, detail: "Network currently carrying traffic", icon: networkIcon, tint: BrandTheme.signalCyan)
                BrandMetricCard(title: "Download now", value: rate(diagnostics.totalDownloadBytesPerSecond), detail: "Across measured physical interfaces", icon: "arrow.down", tint: BrandTheme.networkBlue)
                BrandMetricCard(title: "Upload now", value: rate(diagnostics.totalUploadBytesPerSecond), detail: "Across measured physical interfaces", icon: "arrow.up", tint: BrandTheme.signalCyan)
            }

            BrandCard {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "wrench.and.screwdriver").foregroundStyle(BrandTheme.networkBlue)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Technical measurement view").font(.headline)
                        Text("Monitor exposes interface-level counters for diagnostics. Interface totals and last-sample changes are not the same thing as usage attributed to a Wi-Fi network.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            DiagnosticsView(viewModel: diagnostics)
                .padding(-20)
        }
    }

    private var networkIcon: String {
        diagnostics.currentNetworkName.localizedCaseInsensitiveContains("wi-fi") ? "wifi" : "network"
    }

    private func rate(_ bytesPerSecond: Double) -> String {
        let bytes = Int64(clamping: UInt64(max(0, bytesPerSecond.rounded())))
        return "\(ByteCountFormatter.string(fromByteCount: bytes, countStyle: .decimal))/s"
    }
}

enum DashboardDestination: String, CaseIterable, Identifiable, Hashable {
    case overview, trends, networks, applications, monitor
    var id: Self { self }

    var title: String {
        switch self {
        case .overview: "Overview"
        case .trends: "Trends"
        case .networks: "Networks"
        case .applications: "Applications"
        case .monitor: "Monitor"
        }
    }

    var subtitle: String {
        switch self {
        case .overview: "A clear snapshot of usage, coverage, and the networks that matter most."
        case .trends: "See when traffic grows, where peaks happen, and which network caused them."
        case .networks: "Compare networks, rename them, and inspect evidence quality."
        case .applications: "See process-level activity now, with richer signed evidence when available."
        case .monitor: "Live technical interface counters for measurement diagnostics."
        }
    }

    var icon: String {
        switch self {
        case .overview: "rectangle.3.group"
        case .trends: "chart.xyaxis.line"
        case .networks: "wifi.router"
        case .applications: "square.grid.2x2"
        case .monitor: "waveform.path.ecg"
        }
    }
}
#endif
