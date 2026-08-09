#if os(macOS)
import SwiftUI

struct ApplicationsView: View {
    @ObservedObject var advanced: AdvancedObservabilityController
    @ObservedObject var lightweight: LightweightAppActivityController

    @State private var detailSelection: ApplicationEvidenceSummary?
    @State private var searchText = ""

    private let runtimeCapabilities = AdvancedObservabilityRuntimeCapabilities.current

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                capabilityOverview
                lightweightSection
                advancedSection
            }
            .padding(.bottom, 12)
        }
        .task {
            lightweight.start()
            advanced.refresh()
        }
        .onDisappear { lightweight.stop() }
        .sheet(item: $detailSelection) { summary in
            ApplicationDetailView(summary: summary, byteAccounting: advanced.byteAccounting)
        }
    }

    private var capabilityOverview: some View {
        BrandHeroSurface {
            HStack(alignment: .center, spacing: 22) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Text("APPLICATIONS BETA")
                            .font(.caption.weight(.bold))
                            .tracking(0.8)
                            .foregroundStyle(BrandTheme.signalCyan)
                        BrandStatusPill(text: "Local-only", icon: "lock.fill", tint: BrandTheme.healthy)
                    }

                    Text("See which processes are using the network.")
                        .font(.title2.bold())
                        .foregroundStyle(.white)

                    Text("Traffic Monitoring separates a lightweight activity preview from richer signed evidence, so capability limits stay obvious instead of being hidden.")
                        .font(.callout)
                        .foregroundStyle(.white.opacity(0.72))
                        .frame(maxWidth: 620, alignment: .leading)
                }

                Spacer()

                VStack(alignment: .leading, spacing: 9) {
                    capabilityLine(title: "App Activity Preview", value: lightweight.state.title, icon: "waveform.path.ecg", tint: lightweight.state == .available ? BrandTheme.signalCyan : .white.opacity(0.6))
                    capabilityLine(title: "Advanced Provider", value: advancedProviderLabel, icon: "checkmark.shield", tint: advanced.providerState == .active ? BrandTheme.healthy : .white.opacity(0.6))
                }
                .frame(minWidth: 265, alignment: .leading)
            }
        }
    }

    private func capabilityLine(title: String, value: String, icon: String, tint: Color) -> some View {
        HStack(spacing: 9) {
            Image(systemName: icon).foregroundStyle(tint).frame(width: 20)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.caption2).foregroundStyle(.white.opacity(0.58))
                Text(value).font(.caption.weight(.semibold)).foregroundStyle(.white)
            }
        }
    }

    // MARK: - Lightweight preview

    private var lightweightSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .bottom, spacing: 12) {
                BrandSectionHeader(
                    title: "App Activity Preview",
                    subtitle: "Best-effort process network totals from macOS. No Apple Developer Program or system extension is required.",
                    icon: "square.stack.3d.up"
                )
                Spacer()
                if lightweight.isEnabled {
                    Button { Task { await lightweight.refresh() } } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                }
            }

            BrandCard(accent: BrandTheme.networkBlue.opacity(0.24)) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "info.circle.fill").foregroundStyle(BrandTheme.networkBlue)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Activity preview, not privacy evidence").font(.callout.weight(.semibold))
                        Text("This view can show process-level bytes reported by macOS, but it cannot tell whether that traffic stayed on your Mac, went to your LAN, or reached the Internet. Totals can include activity from before you opened Traffic Monitoring and are not persisted.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if !lightweight.isEnabled {
                BrandCard {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("App Activity Preview is off").font(.headline)
                            Text("Turn it on to sample process-level network totals only while this Applications screen is open.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Turn on preview") { lightweight.setEnabled(true) }.buttonStyle(.borderedProminent)
                    }
                }
            } else if lightweight.state == .failed || lightweight.state == .unavailable {
                BrandCard(accent: BrandTheme.warning.opacity(0.3)) {
                    Label(lightweight.errorMessage ?? "Process activity preview is unavailable.", systemImage: "exclamationmark.triangle.fill")
                        .font(.callout)
                        .foregroundStyle(BrandTheme.warning)
                }
            } else {
                HStack(spacing: 12) {
                    BrandMetricCard(title: "Visible processes", value: "\(lightweight.samples.count)", detail: "Non-zero totals in the latest sample", icon: "square.grid.2x2", tint: BrandTheme.networkBlue)
                    BrandMetricCard(title: "Downloaded", value: bytes(lightweight.totalDownloadedBytes), detail: "Sum of visible process totals", icon: "arrow.down", tint: BrandTheme.networkBlue)
                    BrandMetricCard(title: "Uploaded", value: bytes(lightweight.totalUploadedBytes), detail: "Sum of visible process totals", icon: "arrow.up", tint: BrandTheme.signalCyan)
                    BrandMetricCard(title: "Last sample", value: sampleAge, detail: "Refreshes about every 15 seconds", icon: "clock", tint: BrandTheme.signalCyan)
                }

                BrandCard {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Process activity").font(.headline)
                                Text("Sorted by total bytes in the latest macOS sample.").font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            TextField("Filter processes", text: $searchText)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 220)
                        }

                        if filteredLightweightSamples.isEmpty {
                            ContentUnavailableView(
                                searchText.isEmpty ? "Waiting for network activity" : "No matching processes",
                                systemImage: searchText.isEmpty ? "network" : "magnifyingglass",
                                description: Text(searchText.isEmpty ? "Use an app that accesses the network, then refresh or wait for the next sample." : "Try another process name.")
                            )
                            .frame(minHeight: 250)
                        } else {
                            Table(filteredLightweightSamples) {
                                TableColumn("Process") { row in
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(row.processName).fontWeight(.medium).lineLimit(1)
                                        if let pid = row.processIdentifier { Text("PID \(pid)").font(.caption2).foregroundStyle(.secondary) }
                                    }
                                }.width(min: 220, ideal: 320)
                                TableColumn("Downloaded") { row in Text(bytes(row.downloadedBytes)).monospacedDigit() }.width(min: 110, ideal: 130)
                                TableColumn("Uploaded") { row in Text(bytes(row.uploadedBytes)).monospacedDigit() }.width(min: 110, ideal: 130)
                                TableColumn("Total") { row in Text(bytes(row.totalBytes)).fontWeight(.semibold).monospacedDigit() }.width(min: 110, ideal: 130)
                            }
                            .frame(minHeight: 330)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Signed advanced provider

    private var advancedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .bottom) {
                BrandSectionHeader(
                    title: "Advanced Provider",
                    subtitle: "Experimental signed system-extension path for application identity and Local / External / Unknown flow evidence.",
                    icon: "checkmark.shield"
                )
                Spacer()
                BrandStatusPill(text: advancedProviderLabel, icon: advanced.providerState == .active ? "checkmark.circle.fill" : "signature", tint: advanced.providerState == .active ? BrandTheme.healthy : .secondary)
            }

            if !runtimeCapabilities.canInstallSystemExtension {
                BrandCard {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "signature").font(.title3).foregroundStyle(BrandTheme.warning)
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Signed provider not available in this build").font(.headline)
                            Text("The downloadable ad-hoc build intentionally lacks Apple's system-extension entitlement. Use App Activity Preview above today; the richer provider remains a separate capability for a properly signed build.")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                }
            } else {
                advancedStatusCard

                switch advanced.providerState {
                case .active, .degraded where !advanced.applications.isEmpty:
                    advancedApplicationTable
                case .disabled:
                    advancedEmpty("Advanced Provider is off", "Enable the signed provider in Settings when you want locality-aware flow evidence.", "shield")
                case .providerUnavailable:
                    advancedEmpty("Provider unavailable", "The signed system component is not currently reachable. Core analytics and App Activity Preview continue to work.", "shield.slash")
                case .awaitingApproval:
                    advancedEmpty("Waiting for macOS approval", "Approve the system component in System Settings before advanced flow evidence can appear.", "person.badge.clock")
                case .degraded, .active:
                    advancedEmpty("Waiting for provider evidence", "The provider is active but has not produced usable application flow evidence yet.", "app.badge")
                }
            }
        }
    }

    private var advancedStatusCard: some View {
        BrandCard(accent: BrandTheme.statusColor(for: advanced.providerState).opacity(0.28)) {
            HStack(spacing: 14) {
                Image(systemName: statusIcon).font(.title2).foregroundStyle(BrandTheme.statusColor(for: advanced.providerState)).frame(width: 30)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Advanced Observability · \(advanced.providerState.title)").font(.headline)
                    Text(advanced.statusExplanation).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    Text("Byte accounting").font(.caption).foregroundStyle(.secondary)
                    Text(advanced.byteAccounting.title).font(.callout.weight(.semibold))
                }
            }

            if advanced.providerState == .active || advanced.providerState == .degraded {
                Divider().padding(.vertical, 4)
                HStack(spacing: 24) {
                    diagnostic("Protocol", advanced.snapshot.protocolVersion.map(String.init) ?? "—")
                    diagnostic("Active flows", advanced.snapshot.activeFlowCount.map(String.init) ?? "—")
                    diagnostic("Observed flows", advanced.snapshot.observedFlowCount.map(String.init) ?? "—")
                    diagnostic("Provider since", advanced.snapshot.providerStartedAt.map { $0.formatted(.dateTime.hour().minute().second()) } ?? "—")
                    Spacer()
                    diagnostic("Snapshot", advanced.snapshot.generatedAt.formatted(.dateTime.hour().minute().second()))
                }
            }
        }
    }

    private func diagnostic(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption2).foregroundStyle(.secondary)
            Text(value).font(.caption.weight(.semibold)).monospacedDigit()
        }
    }

    private var advancedApplicationTable: some View {
        BrandCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Observed application flows").font(.headline)
                        Text("Unknown evidence stays explicit and is never forced into Local or External.").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Refresh provider") { advanced.refresh() }
                }

                Table(advanced.applications) {
                    TableColumn("Application") { row in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(displayName(row.applicationIdentifier)).fontWeight(.medium)
                            Text(row.applicationIdentifier).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                        }
                    }.width(min: 220, ideal: 300)
                    TableColumn("Local") { row in advancedLocalityCell(flows: row.localNetworkFlows + row.loopbackFlows, bytes: row.localNetworkBytes + row.loopbackBytes) }.width(min: 100, ideal: 125)
                    TableColumn("External") { row in advancedLocalityCell(flows: row.externalFlows, bytes: row.externalBytes) }.width(min: 100, ideal: 125)
                    TableColumn("Unknown") { row in advancedLocalityCell(flows: row.unknownFlows, bytes: row.unknownBytes) }.width(min: 100, ideal: 125)
                    TableColumn("") { row in Button("Details") { detailSelection = row } }.width(min: 70, ideal: 78)
                }
                .frame(minHeight: 330)

                if advanced.byteAccounting != .validated {
                    Label("Application byte totals remain non-authoritative until controlled real-Mac reconciliation passes.", systemImage: "info.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private func advancedLocalityCell(flows: Int, bytes value: UInt64) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text("\(flows) flow\(flows == 1 ? "" : "s")").monospacedDigit()
            if advanced.byteAccounting == .validated { Text(bytes(value)).font(.caption).foregroundStyle(.secondary).monospacedDigit() }
        }
    }

    private func advancedEmpty(_ title: String, _ description: String, _ icon: String) -> some View {
        BrandCard {
            ContentUnavailableView(title, systemImage: icon, description: Text(description))
                .frame(maxWidth: .infinity, minHeight: 220)
        }
    }

    // MARK: - Helpers

    private var filteredLightweightSamples: [LightweightProcessNetworkSample] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return lightweight.samples }
        return lightweight.samples.filter { $0.processName.localizedCaseInsensitiveContains(query) }
    }

    private var sampleAge: String {
        guard let last = lightweight.lastUpdatedAt else { return "—" }
        let seconds = max(0, Date().timeIntervalSince(last))
        if seconds < 5 { return "Now" }
        if seconds < 60 { return "\(Int(seconds))s ago" }
        return "\(Int(seconds / 60))m ago"
    }

    private var advancedProviderLabel: String {
        runtimeCapabilities.canInstallSystemExtension ? advanced.providerState.title : "Signed build required"
    }

    private var statusIcon: String {
        switch advanced.providerState {
        case .disabled: "shield"
        case .providerUnavailable: "shield.slash"
        case .awaitingApproval: "person.badge.clock"
        case .active: "checkmark.shield.fill"
        case .degraded: "exclamationmark.shield.fill"
        }
    }

    private func displayName(_ identifier: String) -> String {
        guard identifier != "Unknown application" else { return identifier }
        return identifier.split(separator: ".").last.map(String.init) ?? identifier
    }

    private func bytes(_ value: UInt64) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(clamping: value), countStyle: .decimal)
    }
}

private struct ApplicationDetailView: View {
    let summary: ApplicationEvidenceSummary
    let byteAccounting: ByteAccountingCapability
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(summary.applicationIdentifier).font(.title2.bold())
                    Text("Observed advanced-provider flow evidence").foregroundStyle(.secondary)
                }
                Spacer()
                Button("Close") { dismiss() }
            }

            HStack(spacing: 12) {
                evidenceCard("Local flows", summary.localNetworkFlows + summary.loopbackFlows, localBytes, BrandTheme.networkBlue)
                evidenceCard("External flows", summary.externalFlows, summary.externalBytes, BrandTheme.signalCyan)
                evidenceCard("Unknown flows", summary.unknownFlows, summary.unknownBytes, BrandTheme.warning)
            }

            BrandCard {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Evidence boundary").font(.headline)
                    LabeledContent("Byte accounting", value: byteAccounting.title)
                    LabeledContent("Last observed", value: summary.lastObservedAt.formatted(.dateTime.day().month(.abbreviated).year().hour().minute()))
                    Text("This describes observed provider flows only. It does not prove behavior outside provider coverage, and Unknown remains Unknown.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding(22)
        .frame(width: 720, height: 430)
    }

    private var localBytes: UInt64 { summary.localNetworkBytes + summary.loopbackBytes }

    private func evidenceCard(_ title: String, _ flows: Int, _ value: UInt64, _ tint: Color) -> some View {
        BrandMetricCard(
            title: title,
            value: "\(flows)",
            detail: byteAccounting == .validated ? bytes(value) : "Bytes not validated",
            icon: "point.3.connected.trianglepath.dotted",
            tint: tint
        )
    }

    private func bytes(_ value: UInt64) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(clamping: value), countStyle: .decimal)
    }
}
#endif
