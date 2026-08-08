#if os(macOS)
import Combine
import Foundation

@MainActor
final class AppModel: ObservableObject {
    let diagnostics = DiagnosticsViewModel()
    let locationAuthorization = LocationAuthorizationController()

    func start() {
        diagnostics.start()
    }

    func stop() {
        diagnostics.stop()
    }
}
#endif
