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

    init() {
        let store = LocalUsageStore.makeDefault()
        usageStore = store
        diagnostics = DiagnosticsViewModel(usageStore: store)
    }

    func start() {
        diagnostics.start()
        advancedObservability.start()
    }

    func stop() {
        advancedObservability.stop()
        diagnostics.stop()
    }
}
#endif
