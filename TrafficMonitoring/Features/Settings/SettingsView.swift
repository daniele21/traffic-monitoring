#if os(macOS)
import SwiftUI

struct SettingsView: View {
    @ObservedObject var locationAuthorization: LocationAuthorizationController

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
        }
        .formStyle(.grouped)
        .frame(width: 520, height: 360)
    }
}
#endif
