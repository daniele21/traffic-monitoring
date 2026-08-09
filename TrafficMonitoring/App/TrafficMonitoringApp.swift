#if os(macOS)
import SwiftUI

@main
struct TrafficMonitoringApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(diagnostics: model.diagnostics)
                .task { model.start() }
                .tint(BrandTheme.networkBlue)
        } label: {
            Image(systemName: "shield.fill")
                .accessibilityLabel("Traffic Monitoring")
        }
        .menuBarExtraStyle(.window)

        Window("Traffic Monitoring", id: "analytics") {
            DashboardView(
                diagnostics: model.diagnostics,
                usageStore: model.usageStore,
                advancedObservability: model.advancedObservability,
                lightweightAppActivity: model.lightweightAppActivity
            )
            .task { model.start() }
            .tint(BrandTheme.networkBlue)
        }
        .defaultSize(width: 1220, height: 780)

        Window("Traffic Monitoring Settings", id: "settings") {
            SettingsView(
                locationAuthorization: model.locationAuthorization,
                advancedObservability: model.advancedObservability,
                advancedObservabilityInstaller: model.advancedObservabilityInstaller,
                lightweightAppActivity: model.lightweightAppActivity
            )
            .tint(BrandTheme.networkBlue)
        }
        .windowResizability(.contentSize)
    }
}
#endif
