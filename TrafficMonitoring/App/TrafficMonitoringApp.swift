#if os(macOS)
import SwiftUI

@main
struct TrafficMonitoringApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        MenuBarExtra("Traffic", systemImage: "network") {
            MenuBarView(diagnostics: model.diagnostics)
                .task { model.start() }
        }
        .menuBarExtraStyle(.window)

        Window("Network Usage", id: "analytics") {
            DashboardView(diagnostics: model.diagnostics)
                .task { model.start() }
        }
        .defaultSize(width: 1080, height: 700)

        Window("Settings", id: "settings") {
            SettingsView(locationAuthorization: model.locationAuthorization)
        }
        .windowResizability(.contentSize)
    }
}
#endif
