#if os(macOS)
import Combine
import Foundation

@MainActor
final class AppModel: ObservableObject {
    let diagnostics = DiagnosticsViewModel()

    func start() {
        diagnostics.start()
    }

    func stop() {
        diagnostics.stop()
    }
}
#endif
