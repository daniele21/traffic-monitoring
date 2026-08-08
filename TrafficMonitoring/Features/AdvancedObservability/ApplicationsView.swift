#if os(macOS)
import SwiftUI

struct ApplicationsView: View {
    @ObservedObject var advanced: AdvancedObservabilityController
    @State private var detailSelection: ApplicationEvidenceSummary?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            statusCard

            switch advanced.providerState {
            case .disabled:
                unavailable(title: "Advanced Observability is off", description: "Enable it in Settings when you want to inspect app-level flow evidence. Basic network analytics do not require it.", icon: "shield")
            case .providerUnavailable:
                unavailable(title: "Advanced provider unavailable", description: "This development build does not contain an approved, signed Network Extension provider. Core traffic tracking remains fully available.", icon: "shield.slash")
            case .awaitingApproval:
                unavailable(title: "Waiting for macOS approval", description: "Approve the Advanced Observability system component before application flow evidence can appear.", icon: "person.badge.clock")
            case .degraded:
                if advanced.applications.isEmpty { unavailable(title: "Advanced evidence unavailable", description: "The last provider evidence is stale or incomplete. No definitive app-level conclusion is shown.", icon: "exclamationmark.triangle") } else { applicationTable }
            case .active:
                if advanced.applications.isEmpty { unavailable(title: "Waiting for application activity", description: "The provider is active. Use an app that accesses the network and observations will appear here.", icon: "app.badge") } else { applicationTable }
            }
        }
        .sheet(item: $detailSelection) { summary in
            ApplicationDetailView(summary: summary, byteAccounting: advanced.byteAccounting)
        }
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 14) {
                Image(systemName: statusIcon)
                    .font(.title2)
                    .foregroundStyle(BrandTheme.statusColor(for: advanced.providerState))
                    .frame(width: 30)
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
                Divider()
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
        .padding(14)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 12))
        .overlay { RoundedRectangle(cornerRadius: 12).stroke(BrandTheme.networkBlue.opacity(0.18), lineWidth: 1) }
    }

    private func diagnostic(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption2).foregroundStyle(.secondary)
            Text(value).font(.caption.weight(.semibold)).monospacedDigit()
        }
    }

    private var applicationTable: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Applications").font(.title2.weight(.semibold))
                    Text("Observed flow locality by source application. Unknown evidence stays explicit.").foregroundStyle(.secondary)
                }
                Spacer()
                Button("Refresh") { advanced.refresh() }
            }

            Table(advanced.applications) {
                TableColumn("Application") { row in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(displayName(row.applicationIdentifier)).fontWeight(.medium)
                        Text(row.applicationIdentifier).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                }.width(min: 230, ideal: 310)
                TableColumn("Local") { row in localityCell(flows: row.localNetworkFlows + row.loopbackFlows, bytes: row.localNetworkBytes + row.loopbackBytes) }.width(min: 100, ideal: 125)
                TableColumn("External") { row in localityCell(flows: row.externalFlows, bytes: row.externalBytes) }.width(min: 100, ideal: 125)
                TableColumn("Unknown") { row in localityCell(flows: row.unknownFlows, bytes: row.unknownBytes) }.width(min: 100, ideal: 125)
                TableColumn("Last activity") { row in Text(row.lastObservedAt.formatted(.dateTime.day().month(.abbreviated).hour().minute())) }.width(min: 125, ideal: 145)
                TableColumn("") { row in Button("Details") { detailSelection = row } }.width(min: 70, ideal: 78)
            }
            .frame(minHeight: 380)

            if advanced.byteAccounting != .validated {
                Label("Flow attribution is experimental. Byte totals are hidden from authoritative use until B1 byte accounting is validated on real macOS traffic.", systemImage: "info.circle")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func localityCell(flows: Int, bytes: UInt64) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text("\(flows) flow\(flows == 1 ? "" : "s")").monospacedDigit()
            if advanced.byteAccounting == .validated { Text(formatBytes(bytes)).font(.caption).foregroundStyle(.secondary).monospacedDigit() }
        }
    }

    private func unavailable(title: String, description: String, icon: String) -> some View {
        ContentUnavailableView(title, systemImage: icon, description: Text(description)).frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var statusIcon: String {
        switch advanced.providerState { case .disabled: "shield"; case .providerUnavailable: "shield.slash"; case .awaitingApproval: "person.badge.clock"; case .active: "checkmark.shield.fill"; case .degraded: "exclamationmark.shield.fill" }
    }

    private func displayName(_ identifier: String) -> String {
        guard identifier != "Unknown application" else { return identifier }
        return identifier.split(separator: ".").last.map(String.init) ?? identifier
    }

    private func formatBytes(_ bytes: UInt64) -> String { ByteCountFormatter.string(fromByteCount: Int64(clamping: bytes), countStyle: .decimal) }
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
                    Text("Observed application flow evidence").foregroundStyle(.secondary)
                }
                Spacer(); Button("Close") { dismiss() }
            }
            HStack(spacing: 12) {
                card("Local flows", summary.localNetworkFlows + summary.loopbackFlows, localBytes)
                card("External flows", summary.externalFlows, summary.externalBytes)
                card("Unknown flows", summary.unknownFlows, summary.unknownBytes)
            }
            GroupBox("Evidence boundary") {
                VStack(alignment: .leading, spacing: 8) {
                    LabeledContent("Byte accounting", value: byteAccounting.title)
                    LabeledContent("Last observed", value: summary.lastObservedAt.formatted(.dateTime.day().month(.abbreviated).year().hour().minute()))
                    Text("This view describes observed flows. It does not prove an application's behavior outside the provider's coverage period, and unknown flows are never forced into local or external categories.").font(.caption).foregroundStyle(.secondary)
                }.padding(.vertical, 4)
            }
            Spacer()
        }.padding(22).frame(width: 720, height: 430)
    }

    private var localBytes: UInt64 { summary.localNetworkBytes + summary.loopbackBytes }
    private func card(_ title: String, _ flows: Int, _ bytes: UInt64) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text("\(flows)").font(.title2.bold()).monospacedDigit()
            Text(byteAccounting == .validated ? formatBytes(bytes) : "Bytes not validated").font(.caption).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(14).background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 12))
    }
    private func formatBytes(_ bytes: UInt64) -> String { ByteCountFormatter.string(fromByteCount: Int64(clamping: bytes), countStyle: .decimal) }
}
#endif