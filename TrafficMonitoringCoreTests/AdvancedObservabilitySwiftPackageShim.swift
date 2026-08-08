#if SWIFT_PACKAGE
import Foundation

// SwiftPM intentionally compiles only the small platform-independent core source list.
// These equivalents keep locality/aggregation contract tests portable; the actual
// production implementations are compiled and tested by the macOS Xcode target.
enum FlowLocality: String, Equatable { case loopback, localNetwork, external, unknown }

struct ApplicationFlowEvidence {
    let observedAt: Date
    let applicationIdentifier: String?
    let locality: FlowLocality
    let accountedBytes: UInt64?
    init(observedAt: Date, applicationIdentifier: String?, locality: FlowLocality, accountedBytes: UInt64? = nil) {
        self.observedAt = observedAt; self.applicationIdentifier = applicationIdentifier; self.locality = locality; self.accountedBytes = accountedBytes
    }
}

struct ApplicationEvidenceSummary {
    let applicationIdentifier: String
    var loopbackFlows = 0
    var localNetworkFlows = 0
    var externalFlows = 0
    var unknownFlows = 0
    var accountedBytes: UInt64 = 0
    var hasCompleteByteAccounting = true
    var lastObservedAt: Date
    var totalFlows: Int { loopbackFlows + localNetworkFlows + externalFlows + unknownFlows }
}

struct ApplicationEvidenceAggregator {
    func summaries(_ observations: [ApplicationFlowEvidence]) -> [ApplicationEvidenceSummary] {
        var result: [String: ApplicationEvidenceSummary] = [:]
        for observation in observations {
            let app = observation.applicationIdentifier ?? "Unknown application"
            var row = result[app] ?? ApplicationEvidenceSummary(applicationIdentifier: app, lastObservedAt: observation.observedAt)
            switch observation.locality {
            case .loopback: row.loopbackFlows += 1
            case .localNetwork: row.localNetworkFlows += 1
            case .external: row.externalFlows += 1
            case .unknown: row.unknownFlows += 1
            }
            if let bytes = observation.accountedBytes { row.accountedBytes += bytes } else { row.hasCompleteByteAccounting = false }
            row.lastObservedAt = max(row.lastObservedAt, observation.observedAt)
            result[app] = row
        }
        return result.values.sorted { $0.totalFlows > $1.totalFlows }
    }
}

struct IPLocalityClassifier {
    func classify(host raw: String?) -> FlowLocality {
        guard let raw, !raw.isEmpty else { return .unknown }
        let host = raw.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
        if host == "localhost" || host == "::1" || host.hasPrefix("127.") { return .loopback }
        let parts = host.split(separator: ".").compactMap { Int($0) }
        if parts.count == 4 {
            if parts[0] == 10 || (parts[0] == 172 && (16...31).contains(parts[1])) || (parts[0] == 192 && parts[1] == 168) || (parts[0] == 169 && parts[1] == 254) { return .localNetwork }
            return .external
        }
        if host.hasPrefix("fe8") || host.hasPrefix("fe9") || host.hasPrefix("fea") || host.hasPrefix("feb") || host.hasPrefix("fc") || host.hasPrefix("fd") { return .localNetwork }
        return host.contains(":") ? .external : .unknown
    }
}
#endif
