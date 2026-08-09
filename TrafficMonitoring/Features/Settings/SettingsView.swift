#if os(macOS)
import SwiftUI

struct SettingsView: View {
    @ObservedObject var locationAuthorization: LocationAuthorizationController
    @ObservedObject var advancedObservability: AdvancedObservabilityController
    @ObservedObject var advancedObservabilityInstaller: AdvancedObservabilityInstaller
    @ObservedObject var lightweightAppActivity: LightweightAppActivityController
    @State private var showAdvancedEnableConfirmation = false

    private let runtimeCapabilities = AdvancedObservabilityRuntimeCapabilities.current

    var body: some View {
        VStack(spacing: 0) {
            settingsHeader
            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    trackingCard
                    wifiCard
                    applicationsCard
                }
                .padding(22)
            }
        }
        .frame(width: 780, height: 740)
        .confirmationDialog(
            "Enable the signed Advanced Provider?",
            isPresented: $showAdvancedEnableConfirmation,
            titleVisibility: .visible
        ) {
            Button("Install & Enable") {
                advancedObservability.setEnabled(true)
                advancedObservabilityInstaller.activateAndEnable()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("macOS may ask you to approve the Traffic Monitoring system extension. Enabling its content filter can disable another content filter currently active on this Mac. Normal analytics and App Activity Preview do not require it.")
        }
    }

    private var settingsHeader: some View {
        HStack(spacing: 14) {
            BrandProductHeader(
                title: "Settings",
                subtitle: "Control network identification, local data, and application visibility.",
                compact: true
            )
            Spacer()
            BrandStatusPill(text: "Local-first", icon: "lock.shield.fill", tint: BrandTheme.healthy)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 18)
    }

    private var trackingCard: some View {
        BrandCard {
            VStack(alignment: .leading, spacing: 16) {
                BrandSectionHeader(
                    title: "Tracking & data",
                    subtitle: "Core traffic counting is local and independent from all application-level features.",
                    icon: "waveform.path.ecg"
                )
                Divider()
                settingRow(icon: "timer", title: "Sampling", detail: "Physical interface counters are sampled approximately every 2 seconds.", trailing: "2 sec")
                settingRow(icon: "externaldrive.fill.badge.checkmark", title: "History", detail: "Analytics are persisted locally in efficient buckets; no analytics backend is required.", trailing: "On this Mac")
            }
        }
    }

    private var wifiCard: some View {
        BrandCard {
            VStack(alignment: .leading, spacing: 16) {
                BrandSectionHeader(
                    title: "Wi-Fi network names",
                    subtitle: "Location permission is used only so macOS can reveal the current Wi-Fi SSID for local grouping.",
                    icon: "wifi"
                )
                Divider()

                HStack(alignment: .top, spacing: 14) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Network identification").font(.headline)
                        Text("Traffic is still counted when permission is denied. Without the SSID, Wi-Fi usage is grouped under an unnamed network instead of being discarded.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    BrandStatusPill(
                        text: locationAuthorization.statusLabel,
                        icon: locationAuthorization.isAuthorized ? "checkmark.circle.fill" : "location",
                        tint: locationAuthorization.isAuthorized ? BrandTheme.healthy : .secondary
                    )
                }

                if locationAuthorization.canRequest {
                    Button { locationAuthorization.requestForWiFiName() } label: {
                        Label("Allow Wi-Fi network names", systemImage: "location.fill")
                    }
                    .buttonStyle(.borderedProminent)
                } else if locationAuthorization.isAuthorized {
                    Label("Wi-Fi names are available for network grouping.", systemImage: "checkmark.circle.fill")
                        .font(.callout)
                        .foregroundStyle(BrandTheme.healthy)
                } else {
                    Label("Location access is unavailable. You can change it later in System Settings.", systemImage: "info.circle")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var applicationsCard: some View {
        BrandCard(accent: BrandTheme.signalCyan.opacity(0.22)) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top) {
                    BrandSectionHeader(
                        title: "Applications Beta",
                        subtitle: "Two capability levels: a lightweight preview that works today, plus an optional signed provider for richer flow evidence.",
                        icon: "square.grid.2x2"
                    )
                    BrandStatusPill(text: "BETA", tint: BrandTheme.signalCyan)
                }

                Divider()

                lightweightSettings
                Divider()
                signedProviderSettings
            }
        }
    }

    private var lightweightSettings: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("App Activity Preview").font(.headline)
                    Text("Shows best-effort process-level network totals while the Applications screen is open. No Apple Developer Program or privileged component is required.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Toggle(
                    "",
                    isOn: Binding(
                        get: { lightweightAppActivity.isEnabled },
                        set: { lightweightAppActivity.setEnabled($0) }
                    )
                )
                .labelsHidden()
            }

            HStack(spacing: 10) {
                capabilityTile(title: "Availability", value: lightweightAppActivity.state.title, icon: "waveform.path.ecg", tint: lightweightAppActivity.state == .available ? BrandTheme.healthy : .secondary)
                capabilityTile(title: "Locality", value: "Not available", icon: "point.3.connected.trianglepath.dotted", tint: .secondary)
                capabilityTile(title: "Persistence", value: "Live only", icon: "clock", tint: BrandTheme.networkBlue)
            }

            Label("Preview values are activity hints, not privacy evidence. They do not distinguish LAN from Internet traffic and can include process activity from before the preview started.", systemImage: "info.circle")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var signedProviderSettings: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Advanced Provider").font(.headline)
                    Text("Optional signed system-extension path for source application and Local / External / Unknown flow evidence.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                BrandStatusPill(
                    text: runtimeCapabilities.canInstallSystemExtension ? advancedObservability.providerState.title : "Signed build required",
                    icon: runtimeCapabilities.canInstallSystemExtension ? "checkmark.shield" : "signature",
                    tint: runtimeCapabilities.canInstallSystemExtension ? BrandTheme.statusColor(for: advancedObservability.providerState) : BrandTheme.warning
                )
            }

            HStack(spacing: 10) {
                capabilityTile(title: "System component", value: runtimeCapabilities.canInstallSystemExtension ? advancedObservabilityInstaller.state.title : "Not entitled", icon: "signature", tint: runtimeCapabilities.canInstallSystemExtension ? BrandTheme.networkBlue : BrandTheme.warning)
                capabilityTile(title: "Provider", value: advancedObservability.providerState.title, icon: "network.badge.shield.half.filled", tint: BrandTheme.statusColor(for: advancedObservability.providerState))
                capabilityTile(title: "Byte accounting", value: advancedObservability.byteAccounting.title, icon: "number", tint: advancedObservability.byteAccounting == .validated ? BrandTheme.healthy : .secondary)
            }

            if runtimeCapabilities.canInstallSystemExtension {
                HStack {
                    Button { showAdvancedEnableConfirmation = true } label: {
                        Label("Install & enable provider", systemImage: "shield.lefthalf.filled")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isInstallationBusy)

                    Button("Disable filter") { advancedObservabilityInstaller.disableFilter() }
                        .disabled(advancedObservabilityInstaller.state == .disabling)

                    Spacer()
                    Button { advancedObservability.refresh() } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                }
            } else {
                BrandCard(padding: 12, accent: BrandTheme.warning.opacity(0.28)) {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "signature").foregroundStyle(BrandTheme.warning)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Nothing is broken").font(.callout.weight(.semibold))
                            Text("This ad-hoc build cannot install Apple's system extension. Use App Activity Preview for process-level visibility; Overview, Trends, Networks, Monitor, history, and export all remain fully available.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Label("A signed provider reports aggregate flow metadata only. Packet payloads and browsing content are not stored or sent to the app.", systemImage: "hand.raised.fill")
                .font(.caption)
                .foregroundStyle(.secondary)
            Label("macOS allows one active content-filter configuration at a time, so enabling the signed provider can replace another active filter.", systemImage: "exclamationmark.shield")
                .font(.caption)
                .foregroundStyle(BrandTheme.warning)

            if runtimeCapabilities.canInstallSystemExtension,
               let error = advancedObservabilityInstaller.lastError ?? advancedObservability.lastError {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(BrandTheme.critical)
            }
        }
    }

    private func settingRow(icon: String, title: String, detail: String, trailing: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).foregroundStyle(BrandTheme.networkBlue).frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.callout.weight(.semibold))
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text(trailing).font(.callout.weight(.medium)).foregroundStyle(.secondary)
        }
    }

    private func capabilityTile(title: String, value: String, icon: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Label(title, systemImage: icon).font(.caption2).foregroundStyle(tint)
            Text(value).font(.caption.weight(.semibold)).lineLimit(1)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(0.07), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var isInstallationBusy: Bool {
        switch advancedObservabilityInstaller.state {
        case .requestingActivation, .awaitingUserApproval, .configuringFilter, .disabling: true
        case .idle, .enabled, .restartRequired, .disabled, .failed: false
        }
    }
}
#endif
