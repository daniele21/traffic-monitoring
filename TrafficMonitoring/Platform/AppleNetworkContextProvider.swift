#if os(macOS)
import Foundation
import Network
import OSLog

final class AppleNetworkContextProvider: NetworkContextProviding, @unchecked Sendable {
    private struct PathState {
        var status: PathStatus = .unknown
        var isExpensive = false
        var isConstrained = false
    }

    private let monitor: NWPathMonitor
    private let queue = DispatchQueue(label: "com.daniele21.trafficmonitoring.path-monitor")
    private let lock = NSLock()
    private let wifi = WiFiContextProvider()
    private var state = PathState()

    init() {
        monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self else { return }
            let newState = PathState(
                status: Self.mapStatus(path.status),
                isExpensive: path.isExpensive,
                isConstrained: path.isConstrained
            )
            lock.lock()
            state = newState
            lock.unlock()
            Logger.context.debug(
                "Path updated: status=\(String(describing: newState.status), privacy: .public) expensive=\(newState.isExpensive) constrained=\(newState.isConstrained)"
            )
        }
        monitor.start(queue: queue)
    }

    deinit {
        monitor.cancel()
    }

    func currentSnapshot() async -> NetworkContextSnapshot {
        lock.lock()
        let pathState = state
        lock.unlock()
        return NetworkContextSnapshot(
            pathStatus: pathState.status,
            isExpensive: pathState.isExpensive,
            isConstrained: pathState.isConstrained,
            wifiSSIDByInterface: wifi.currentSSIDByInterface()
        )
    }

    private static func mapStatus(_ status: NWPath.Status) -> PathStatus {
        switch status {
        case .satisfied:
            return .satisfied
        case .unsatisfied:
            return .unsatisfied
        case .requiresConnection:
            return .requiresConnection
        @unknown default:
            return .unknown
        }
    }
}
#endif
