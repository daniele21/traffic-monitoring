#if os(macOS)
import SwiftUI

struct SettingsView: View {
    @ObservedObject var locationAuthorization: LocationAuthorizationController
    @ObservedObject var advancedObservability: AdvancedObservabilityController
    @ObservedObject var advancedObservabilityInstaller: AdvancedObservabilityInstaller
    @State private var showAdvancedEnableConfirmation = false

    var body: some View {
        Form {
            Section("Tracking") {
                LabeledContent("Sample interval", value: "2 seconds")
                Text("Traffic counting is local-only and does not depend on Location access.")
                    .foregroundStyle(.secondary)
            }

            Section("Wi-Fi network names") {
                LabeledContent("Location permission", value: locationAuthorization.statusLabel)
                Text("macOS protects the current Wi-Fi SSID behind Location permission. Traffic continues to be counted if you deny it; the network is then grouped as an unnamed Wi-Fi connection.")
                    .foregroundStyle(.secondary)

                if locationAuthorization.canRequest {
                    Button("Allow Wi-Fi Network Names") {
                        locationAuthorization.requestForWiFiName()
                    }
                } else if locationAuthorization.isAuthorized {
                    Label("Wi-Fi network names can be used for local grouping.", systemImage: "checkmark.circle")
                        .foregroundStyle(.secondary)
                } else {
                    Text("Permission is unavailable. You can change Location access later in System Settings.")
                        .foregroundStyle(.secondary)
                }
            }

            Section("Advanced Observability · Experimental") {
                Toggle(
                    "Show Applications view",
                    isOn: Binding(
                        get: { advancedObservability.isEnabled },
                        set: { advancedObservability.setEnabled($0) }
                    )
                )

                LabeledContent("System component", value: advancedObservabilityInstaller.state.title)
                LabeledContent("Provider", value: advancedObservability.providerState.title)
                LabeledContent("Byte accounting", value: advancedObservability.byteAccounting.title)
                LabeledContent("Evidence bridge", value: advancedObservability.bridgeStatus)

                Text(advancedObservabilityInstaller.message)
                    .foregroundStyle(.secondary)

                HStack {
                    Button("Install & Enable Advanced Observability") {
                        showAdvancedEnableConfirmation = true
                    }
                    .disabled(isInstallationBusy)

                    Button("Disable Filter") {
                        advancedObservabilityInstaller.disableFilter()
                    }
                    .disabled(advancedObservabilityInstaller.state == .disabling)

                    Spacer()

                    Button("Refresh Evidence") {
                        advancedObservability.refresh()
                    }
                }

                Text("Advanced Observability is optional and separate from normal traffic tracking. When enabled with a properly signed build, macOS activates a Network Extension system component that reports aggregate source-application and local/external/unknown flow evidence. Packet payloads and browsing content are not stored or sent to the app.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Label("macOS allows one active content-filter configuration at a time. Enabling this experimental mode can disable another content filter already active on the Mac. Traffic Monitoring asks before doing so and core Analytics never requires this mode.", systemImage: "exclamationmark.shield")
                    .font(.caption)
                    .foregroundStyle(BrandTheme.warning)

                if advancedObservabilityInstaller.state == .awaitingUserApproval {
                    Label("macOS is waiting for approval. Follow the System Settings prompt, then return here; activation continues automatically after approval.", systemImage: "person.badge.clock")
                        .font(.caption)
                        .foregroundStyle(BrandTheme.warning)
                }

                if advancedObservabilityInstaller.state == .restartRequired {
                    Label("Restart your Mac to complete the system-extension update.", systemImage: "restart")
                        .font(.caption)
                        .foregroundStyle(BrandTheme.warning)
                }

                if advancedObservability.providerState == .providerUnavailable {
                    Label("The downloadable ad-hoc CI build can run all core network analytics, but macOS will not activate its Advanced Observability system extension without the required Apple entitlements and signing. This is reported as unavailable rather than simulated.", systemImage: "info.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let error = advancedObservabilityInstaller.lastError ?? advancedObservability.lastError {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(BrandTheme.critical)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 700, height: 750)
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
