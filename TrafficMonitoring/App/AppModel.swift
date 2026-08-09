#if os(macOS)
import Combine
import Foundation

@MainActor
final class AppModel: ObservableObject {
    let usageStore: LocalUsageStore
    let diagnostics: DiagnosticsViewModel
    let locationAuthorization = LocationAuthorizationController()
    let advancedObservability = AdvancedObservabilityController()
    let advancedObservabilityInstaller = AdvancedObservabilityInstaller()
    let lightweightAppActivity = LightweightAppActivityController()

    init() {
        let store = LocalUsageStore.makeDefault()
        usageStore = store
        diagnostics = DiagnosticsViewModel(usageStore: store)
    }

    func start() {
        diagnostics.start()
        advancedObservability.start()
        // Lightweight process activity is sampled only while the Applications
        // view is visible, avoiding a background nettop process when unused.
    }

    func stop() {
        lightweightAppActivity.stop()
        advancedObservability.stop()
        diagnostics.stop()
    }
}
#endif
