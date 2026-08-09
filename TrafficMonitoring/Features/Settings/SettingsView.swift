#if os(macOS)
import SwiftUI

struct SettingsView: View {
    @ObservedObject var locationAuthorization: LocationAuthorizationController
    @ObservedObject var advancedObservability: AdvancedObservabilityController
    @ObservedObject var advancedObservabilityInstaller: AdvancedObservabilityInstaller
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
                    advancedCard
                }
                .padding(22)
            }
        }
        .frame(width: 760, height: 720)
        .confirmationDialog(
            "Enable Advanced Observability?",
            isPresented: $showAdvancedEnableConfirmation,
            titleVisibility: .visible
        ) {
            Button("Install & Enable") {
                advancedObservability.setEnabled(true)
                advancedObservabilityInstaller.activateAndEnable()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("macOS may ask you to approve the Traffic Monitoring system extension. Enabling its content filter can disable another content filter currently active on this Mac. Normal Traffic Monitoring analytics do not need this feature.")
        }
    }

    private var settingsHeader: some View {
        HStack(spacing: 14) {
            BrandProductHeader(
                title: "Settings",
                subtitle: "Control network identification, local data, and experimental application visibility.",
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
                    subtitle: "Core traffic counting works locally and does not depend on the experimental system component.",
                    icon: "waveform.path.ecg"
                )

                Divider()

                settingRow(
                    icon: "timer",
                    title: "Sampling",
                    detail: "Physical interface counters are sampled approximately every 2 seconds.",
                    trailing: "2 sec"
                )

                settingRow(
                    icon: "externaldrive.fill.badge.checkmark",
                    title: "History",
                    detail: "Analytics are persisted locally in efficient buckets; no analytics backend is required.",
                    trailing: "On this Mac"
                )
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
                        Text("Network identification")
                            .font(.headline)
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
                    Button {
                        locationAuthorization.requestForWiFiName()
                    } label: {
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

    private var advancedCard: some View {
        BrandCard(accent: BrandTheme.signalCyan.opacity(0.22)) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top) {
                    BrandSectionHeader(
                        title: "Applications Beta",
                        subtitle: "Optional app-level network visibility. Core analytics remain fully usable when this is off or unavailable.",
                        icon: "square.grid.2x2"
                    )
                    BrandStatusPill(text: "BETA", tint: BrandTheme.signalCyan)
                }

                Divider()

                Toggle(
                    "Enable Applications Beta",
                    isOn: Binding(
                        get: { advancedObservability.isEnabled },
                        set: { advancedObservability.setEnabled($0) }
                    )
                )
                .font(.headline)

                HStack(spacing: 10) {
                    capabilityTile(
                        title: "System component",
                        value: runtimeCapabilities.canInstallSystemExtension ? advancedObservabilityInstaller.state.title : "Requires signed build",
                        icon: runtimeCapabilities.canInstallSystemExtension ? "checkmark.shield" : "signature",
                        tint: runtimeCapabilities.canInstallSystemExtension ? BrandTheme.networkBlue : BrandTheme.warning
                    )
                    capabilityTile(
                        title: "Provider",
                        value: advancedObservability.providerState.title,
                        icon: "network.badge.shield.half.filled",
                        tint: BrandTheme.statusColor(for: advancedObservability.providerState)
                    )
                    capabilityTile(
                        title: "Byte accounting",
                        value: advancedObservability.byteAccounting.title,
                        icon: "number",
                        tint: advancedObservability.byteAccounting == .validated ? BrandTheme.healthy : .secondary
                    )
                }

                if runtimeCapabilities.canInstallSystemExtension {
                    HStack {
                        Button {
                            showAdvancedEnableConfirmation = true
                        } label: {
                            Label("Install & enable provider", systemImage: "shield.lefthalf.filled")
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isInstallationBusy)

                        Button("Disable filter") {
                            advancedObservabilityInstaller.disableFilter()
                        }
                        .disabled(advancedObservabilityInstaller.state == .disabling)

                        Spacer()

                        Button {
                            advancedObservability.refresh()
                        } label: {
                            Label("Refresh", systemImage: "arrow.clockwise")
                        }
                    }
                } else {
                    BrandCard(padding: 12, accent: BrandTheme.warning.opacity(0.28)) {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "signature")
                                .foregroundStyle(BrandTheme.warning)
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Advanced provider unavailable in this build")
                                    .font(.callout.weight(.semibold))
                                Text("This ad-hoc build is intentionally missing Apple's system-extension entitlement. Nothing is broken: Overview, Trends, Networks, Monitor, local history, and export continue to work normally.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Label(
                    "A signed provider can observe aggregate source-application flow metadata. Packet payloads and browsing content are not stored or sent to the app.",
                    systemImage: "hand.raised.fill"
                )
                .font(.caption)
                .foregroundStyle(.secondary)

                Label(
                    "macOS allows one active content-filter configuration at a time. Enabling the signed provider can replace another active content filter, so Traffic Monitoring always asks first.",
                    systemImage: "exclamationmark.shield"
                )
                .font(.caption)
                .foregroundStyle(BrandTheme.warning)

                if runtimeCapabilities.canInstallSystemExtension,
                   advancedObservabilityInstaller.state == .awaitingUserApproval {
                    Label("macOS is waiting for approval in System Settings.", systemImage: "person.badge.clock")
                        .font(.caption)
                        .foregroundStyle(BrandTheme.warning)
                }

                if runtimeCapabilities.canInstallSystemExtension,
                   advancedObservabilityInstaller.state == .restartRequired {
                    Label("Restart your Mac to complete the system-extension update.", systemImage: "restart")
                        .font(.caption)
                        .foregroundStyle(BrandTheme.warning)
                }

                if runtimeCapabilities.canInstallSystemExtension,
                   let error = advancedObservabilityInstaller.lastError ?? advancedObservability.lastError {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(BrandTheme.critical)
                }
            }
        }
    }

    private func settingRow(icon: String, title: String, detail: String, trailing: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(BrandTheme.networkBlue)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.callout.weight(.semibold))
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text(trailing)
                .font(.callout.weight(.medium))
                .foregroundStyle(.secondary)
        }
    }

    private func capabilityTile(title: String, value: String, icon: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Label(title, systemImage: icon)
                .font(.caption2)
                .foregroundStyle(tint)
            Text(value)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(0.07), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var isInstallationBusy: Bool {
        switch advancedObservabilityInstaller.state {
        case .requestingActivation, .awaitingUserApproval, .configuringFilter, .disabling:
            true
        case .idle, .enabled, .restartRequired, .disabled, .failed:
            false
        }
    }
}
#endif
