import Foundation
import Network
import NetworkExtension
import OSLog

final class FilterDataProvider: NEFilterDataProvider {
    private let logger = Logger(subsystem: "com.daniele21.trafficmonitoring", category: "advanced-observability")

    override func startFilter(completionHandler: @escaping (Error?) -> Void) {
        logger.notice("Experimental advanced observability provider started")
        completionHandler(nil)
    }

    override func stopFilter(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        logger.notice("Experimental advanced observability provider stopped: \(String(describing: reason), privacy: .public)")
        completionHandler()
    }

    override func handleNewFlow(_ flow: NEFilterFlow) -> NEFilterNewFlowVerdict {
        let applicationIdentifier = flow.sourceAppIdentifier ?? "unknown-application"
        let remoteEndpoint = (flow as? NEFilterSocketFlow)?.remoteEndpoint
        let endpointDescription = remoteEndpoint.map(String.init(describing:)) ?? "unknown-endpoint"
        let locality = LocalityProbe.classify(endpointDescription: endpointDescription)

        // B1 deliberately records metadata only in diagnostics. Payload data is never
        // retained or inspected. A production bridge must aggregate/redact before persistence.
        logger.debug(
            "flow app=\(applicationIdentifier, privacy: .public) locality=\(locality.rawValue, privacy: .public) endpointPresent=\(remoteEndpoint != nil, privacy: .public)"
        )

        return .allow()
    }
}

private enum ProbeLocality: String {
    case loopback
    case localNetwork
    case external
    case unknown
}

private enum LocalityProbe {
    static func classify(endpointDescription: String) -> ProbeLocality {
        let value = endpointDescription.lowercased()
        if value.contains("127.0.0.1") || value.contains("::1") || value.contains("localhost") {
            return .loopback
        }
        if value.contains("10.") || value.contains("192.168.") || containsPrivate172(value) || value.contains("fe80:") || value.contains("fc") || value.contains("fd") {
            return .localNetwork
        }
        if value == "unknown-endpoint" || value.isEmpty {
            return .unknown
        }
        return .external
    }

    private static func containsPrivate172(_ value: String) -> Bool {
        for second in 16...31 where value.contains("172.\(second).") {
            return true
        }
        return false
    }
}
