#if os(macOS)
import SwiftUI

struct SettingsView: View {
    var body: some View {
        Form {
            Section("Tracking") {
                LabeledContent("Sample interval", value: "2 seconds")
                Text("Tracking is local-only. SSID access gracefully degrades when macOS does not expose the Wi-Fi name.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 480, height: 260)
    }
}
#endif
