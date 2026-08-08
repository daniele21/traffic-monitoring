#if os(macOS)
import Combine
import Foundation

@MainActor
final class AppModel: ObservableObject {
    let usageStore: LocalUsageStore
    let diagnostics: DiagnosticsViewModel
    let locationAuthorization = LocationAuthorizationController()

    init() {
        let store = LocalUsageStore.makeDefault()
        usageStore = store
        diagnostics = DiagnosticsViewModel(usageStore: store)
    }

    func start() {
        diagnostics.start()
    }

    func stop() {
        diagnostics.stop()
    }
}
#endif
