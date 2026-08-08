#if os(macOS)
import Combine
import CoreLocation
import Foundation

@MainActor
final class LocationAuthorizationController: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published private(set) var status: CLAuthorizationStatus

    private let manager: CLLocationManager

    override init() {
        let manager = CLLocationManager()
        self.manager = manager
        self.status = manager.authorizationStatus
        super.init()
        manager.delegate = self
    }

    var canRequest: Bool {
        status == .notDetermined
    }

    var isAuthorized: Bool {
        status == .authorizedAlways
    }

    var statusLabel: String {
        switch status {
        case .notDetermined:
            return "Not requested"
        case .restricted:
            return "Restricted"
        case .denied:
            return "Denied"
        case .authorizedAlways:
            return "Allowed"
        @unknown default:
            return "Unknown"
        }
    }

    func requestForWiFiName() {
        guard canRequest else { return }
        manager.requestWhenInUseAuthorization()
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let newStatus = manager.authorizationStatus
        Task { @MainActor [weak self] in
            self?.status = newStatus
        }
    }
}
#endif
