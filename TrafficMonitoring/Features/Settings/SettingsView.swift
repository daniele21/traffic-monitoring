#if os(macOS)
import SwiftUI

struct SettingsView: View {
    @ObservedObject var locationAuthorization: LocationAuthorizationController
    @ObservedObject var advancedObservability: AdvancedObservabilityController

    var body: some View {
        Form {
            Section("Tracking") {
                LabeledContent("Sample interval", value: "2 seconds")
                Text("Traffic counting is local-only and does not depend on Location access.").foregroundStyle(.secondary)
            }

            Section("Wi-Fi network names") {
                LabeledContent("Location permission", value: locationAuthorization.statusLabel)
                Text("macOS protects the current Wi-Fi SSID behind Location permission. Traffic continues to be counted if you deny it; the network is then grouped as an unnamed Wi-Fi connection.").foregroundStyle(.secondary)
                if locationAuthorization.canRequest {
                    Button("Allow Wi-Fi Network Names") { locationAuthorization.requestForWiFiName() }
                } else if locationAuthorization.isAuthorized {
                    Label("Wi-Fi network names can be used for local grouping.", systemImage: "checkmark.circle").foregroundStyle(.secondary)
                } else {
                    Text("Permission is unavailable. You can change Location access later in System Settings.").foregroundStyle(.secondary)
                }
            }

            Section("Advanced Observability · Experimental") {
                Toggle("Enable app-level observability UI", isOn: Binding(get: { advancedObservability.isEnabled }, set: { advancedObservability.setEnabled($0) }))
                LabeledContent("Provider", value: advancedObservability.providerState.title)
                LabeledContent("Byte accounting", value: advancedObservability.byteAccounting.title)
                LabeledContent("Bridge", value: advancedObservability.bridgeStatus)
                Text(advancedObservability.statusExplanation).foregroundStyle(.secondary)
                Text("Advanced mode is optional and separate from normal traffic tracking. Its intended metadata is source app identity plus local/external/unknown flow classification. Packet payloads and browsing content are not part of the design.")
                    .font(.caption).foregroundStyle(.secondary)
                if advancedObservability.providerState == .providerUnavailable {
                    Label("A real provider requires Apple Network Extension entitlements, a signed system extension, user approval and notarized/distributed packaging. The ad-hoc CI app intentionally does not pretend this is active.", systemImage: "info.circle")
                        .font(.caption).foregroundStyle(.secondary)
                }
                if let error = advancedObservability.lastError {
                    Label(error, systemImage: "exclamationmark.triangle").font(.caption).foregroundStyle(BrandTheme.critical)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 620, height: 610)
    }
}
#endif
