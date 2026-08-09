#if os(macOS)
import Combine
import Foundation
import NetworkExtension
import SystemExtensions

enum AdvancedObservabilityInstallationState: String {
    case idle
    case requestingActivation
    case awaitingUserApproval
    case configuringFilter
    case enabled
    case restartRequired
    case disabling
    case disabled
    case failed

    var title: String {
        switch self {
        case .idle: "Not configured"
        case .requestingActivation: "Requesting activation"
        case .awaitingUserApproval: "Awaiting macOS approval"
        case .configuringFilter: "Configuring network filter"
        case .enabled: "Enabled"
        case .restartRequired: "Restart required"
        case .disabling: "Disabling"
        case .disabled: "Disabled"
        case .failed: "Setup failed"
        }
    }
}

final class AdvancedObservabilityInstaller: NSObject, ObservableObject, OSSystemExtensionRequestDelegate {
    static let extensionIdentifier = "com.daniele21.trafficmonitoring.filter"

    @Published private(set) var state: AdvancedObservabilityInstallationState = .idle
    @Published private(set) var message = "Advanced Observability has not been enabled."
    @Published private(set) var lastError: String?

    private enum RequestKind { case activation, deactivation }

    private let requestQueue = DispatchQueue(label: "com.daniele21.trafficmonitoring.system-extension-request")
    private let requestLock = NSLock()
    private var requestKinds: [ObjectIdentifier: RequestKind] = [:]

    func activateAndEnable() {
        setState(.requestingActivation, message: "Requesting activation of the optional Traffic Monitoring system extension.")

        let request = OSSystemExtensionRequest.activationRequest(
            forExtensionWithIdentifier: Self.extensionIdentifier,
            queue: requestQueue
        )
        register(request, as: .activation)
        request.delegate = self
        OSSystemExtensionManager.shared.submitRequest(request)
    }

    func disableFilter() {
        setState(.disabling, message: "Disabling Advanced Observability. Core traffic tracking remains active.")
        let manager = NEFilterManager.shared()
        manager.loadFromPreferences { [weak self] error in
            guard let self else { return }
            if let error {
                self.fail("Could not load the current filter configuration: \(error.localizedDescription)")
                return
            }

            manager.isEnabled = false
            manager.saveToPreferences { [weak self] error in
                if let error {
                    self?.fail("Could not disable the network filter: \(error.localizedDescription)")
                } else {
                    self?.setState(.disabled, message: "Advanced Observability is disabled. Core traffic tracking continues normally.")
                }
            }
        }
    }

    func deactivateSystemExtension() {
        setState(.disabling, message: "Requesting deactivation of the Advanced Observability system extension.")
        let request = OSSystemExtensionRequest.deactivationRequest(
            forExtensionWithIdentifier: Self.extensionIdentifier,
            queue: requestQueue
        )
        register(request, as: .deactivation)
        request.delegate = self
        OSSystemExtensionManager.shared.submitRequest(request)
    }

    // MARK: - OSSystemExtensionRequestDelegate

    func request(_ request: OSSystemExtensionRequest, didFinishWithResult result: OSSystemExtensionRequest.Result) {
        let kind = takeKind(for: request) ?? .activation

        switch result {
        case .completed:
            switch kind {
            case .activation:
                configureFilter()
            case .deactivation:
                setState(.disabled, message: "The Advanced Observability system extension was deactivated. Core traffic tracking remains available.")
            }
        case .willCompleteAfterReboot:
            setState(.restartRequired, message: "macOS accepted the system-extension change. Restart your Mac to complete it.")
        @unknown default:
            setState(.failed, message: "macOS returned an unknown system-extension result.", error: "Unknown system-extension result")
        }
    }

    func request(_ request: OSSystemExtensionRequest, didFailWithError error: Error) {
        _ = takeKind(for: request)
        fail("System extension request failed: \(error.localizedDescription)")
    }

    func requestNeedsUserApproval(_ request: OSSystemExtensionRequest) {
        setState(.awaitingUserApproval, message: "Approve Traffic Monitoring in System Settings to continue enabling Advanced Observability.")
    }

    func request(
        _ request: OSSystemExtensionRequest,
        actionForReplacingExtension existing: OSSystemExtensionProperties,
        withExtension ext: OSSystemExtensionProperties
    ) -> OSSystemExtensionRequest.ReplacementAction {
        .replace
    }

    // MARK: - Content filter configuration

    private func configureFilter() {
        setState(.configuringFilter, message: "The system extension is active. Configuring macOS to report socket and browser flows.")

        let manager = NEFilterManager.shared()
        manager.loadFromPreferences { [weak self] error in
            guard let self else { return }
            if let error {
                self.fail("Could not load Network Extension preferences: \(error.localizedDescription)")
                return
            }

            let configuration = NEFilterProviderConfiguration()
            configuration.filterSockets = true
            configuration.filterBrowsers = true
            configuration.filterDataProviderBundleIdentifier = Self.extensionIdentifier

            manager.localizedDescription = "Traffic Monitoring Advanced Observability"
            manager.providerConfiguration = configuration
            manager.isEnabled = true

            manager.saveToPreferences { [weak self] error in
                if let error {
                    self?.fail("The system extension was activated, but macOS could not enable its content-filter configuration: \(error.localizedDescription)")
                } else {
                    self?.setState(.enabled, message: "Advanced Observability is enabled. Application evidence will appear after the provider observes network activity.")
                }
            }
        }
    }

    private func register(_ request: OSSystemExtensionRequest, as kind: RequestKind) {
        requestLock.lock()
        requestKinds[ObjectIdentifier(request)] = kind
        requestLock.unlock()
    }

    private func takeKind(for request: OSSystemExtensionRequest) -> RequestKind? {
        requestLock.lock()
        defer { requestLock.unlock() }
        return requestKinds.removeValue(forKey: ObjectIdentifier(request))
    }

    private func fail(_ message: String) {
        setState(.failed, message: message, error: message)
    }

    private func setState(_ state: AdvancedObservabilityInstallationState, message: String, error: String? = nil) {
        DispatchQueue.main.async { [weak self] in
            self?.state = state
            self?.message = message
            self?.lastError = error
        }
    }
}
#endif
