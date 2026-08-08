import Foundation
import Network
import NetworkExtension
import Security

final class ProviderEvidenceStore {
    static let shared = ProviderEvidenceStore()
    static let protocolVersion = 1

    private struct FlowState {
        let applicationIdentifier: String
        let locality: String
        var reportedBytes: UInt64
    }

    private struct AppAggregate: Codable {
        let applicationIdentifier: String
        var loopbackFlows: Int = 0
        var localNetworkFlows: Int = 0
        var externalFlows: Int = 0
        var unknownFlows: Int = 0
        var loopbackBytes: UInt64 = 0
        var localNetworkBytes: UInt64 = 0
        var externalBytes: UInt64 = 0
        var unknownBytes: UInt64 = 0
        var accountedBytes: UInt64 = 0
        var hasCompleteByteAccounting: Bool = true
        var lastObservedAt: Date
    }

    private struct Snapshot: Codable {
        let providerState: String
        let byteAccounting: String
        let applications: [AppAggregate]
        let lastObservedAt: Date?
        let generatedAt: Date
        let protocolVersion: Int
        let providerStartedAt: Date
        let activeFlowCount: Int
        let observedFlowCount: Int
    }

    private let queue = DispatchQueue(label: "com.daniele21.trafficmonitoring.provider-evidence")
    private var flows: [UUID: FlowState] = [:]
    private var applications: [String: AppAggregate] = [:]
    private var providerStartedAt = Date()
    private var observedFlowCount = 0

    private init() {}

    func markProviderStarted(at date: Date = Date()) {
        queue.sync {
            providerStartedAt = date
        }
    }

    func register(flow: NEFilterFlow, observedAt: Date = Date()) {
        let identity = ApplicationIdentityResolver.signingIdentifier(from: flow.sourceAppAuditToken) ?? "Unknown application"
        let locality = LocalityClassifier.classify(flow: flow)

        queue.sync {
            guard flows[flow.identifier] == nil else { return }
            flows[flow.identifier] = FlowState(applicationIdentifier: identity, locality: locality, reportedBytes: 0)
            observedFlowCount += 1
            var aggregate = applications[identity] ?? AppAggregate(applicationIdentifier: identity, lastObservedAt: observedAt)
            incrementFlowCount(&aggregate, locality: locality)
            aggregate.lastObservedAt = max(aggregate.lastObservedAt, observedAt)
            applications[identity] = aggregate
        }
    }

    func record(report: NEFilterReport, observedAt: Date = Date()) {
        guard let flow = report.flow else { return }
        let isFinalReport: Bool
        switch report.event {
        case .statistics:
            isFinalReport = false
        case .flowClosed:
            isFinalReport = true
        default:
            return
        }

        let total = saturatingAdd(UInt64(max(0, report.bytesInboundCount)), UInt64(max(0, report.bytesOutboundCount)))

        queue.sync {
            if flows[flow.identifier] == nil {
                let identity = ApplicationIdentityResolver.signingIdentifier(from: flow.sourceAppAuditToken) ?? "Unknown application"
                let locality = LocalityClassifier.classify(flow: flow)
                flows[flow.identifier] = FlowState(applicationIdentifier: identity, locality: locality, reportedBytes: 0)
                observedFlowCount += 1
                var aggregate = applications[identity] ?? AppAggregate(applicationIdentifier: identity, lastObservedAt: observedAt)
                incrementFlowCount(&aggregate, locality: locality)
                applications[identity] = aggregate
            }

            guard var state = flows[flow.identifier] else { return }
            let delta = total >= state.reportedBytes ? total - state.reportedBytes : total
            state.reportedBytes = total

            var aggregate = applications[state.applicationIdentifier] ?? AppAggregate(applicationIdentifier: state.applicationIdentifier, lastObservedAt: observedAt)
            aggregate.accountedBytes = saturatingAdd(aggregate.accountedBytes, delta)
            addBytes(&aggregate, locality: state.locality, bytes: delta)
            aggregate.lastObservedAt = max(aggregate.lastObservedAt, observedAt)
            applications[state.applicationIdentifier] = aggregate

            if isFinalReport {
                flows.removeValue(forKey: flow.identifier)
            } else {
                flows[flow.identifier] = state
            }
        }
    }

    func snapshotData(now: Date = Date()) -> Data? {
        queue.sync {
            let values = applications.values.sorted { $0.applicationIdentifier.localizedCaseInsensitiveCompare($1.applicationIdentifier) == .orderedAscending }
            let snapshot = Snapshot(
                providerState: "active",
                byteAccounting: "notValidated",
                applications: values,
                lastObservedAt: values.map(\.lastObservedAt).max(),
                generatedAt: now,
                protocolVersion: Self.protocolVersion,
                providerStartedAt: providerStartedAt,
                activeFlowCount: flows.count,
                observedFlowCount: observedFlowCount
            )
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.sortedKeys]
            return try? encoder.encode(snapshot)
        }
    }

    private func incrementFlowCount(_ app: inout AppAggregate, locality: String) {
        switch locality {
        case "loopback": app.loopbackFlows += 1
        case "localNetwork": app.localNetworkFlows += 1
        case "external": app.externalFlows += 1
        default: app.unknownFlows += 1
        }
    }

    private func addBytes(_ app: inout AppAggregate, locality: String, bytes: UInt64) {
        switch locality {
        case "loopback": app.loopbackBytes = saturatingAdd(app.loopbackBytes, bytes)
        case "localNetwork": app.localNetworkBytes = saturatingAdd(app.localNetworkBytes, bytes)
        case "external": app.externalBytes = saturatingAdd(app.externalBytes, bytes)
        default: app.unknownBytes = saturatingAdd(app.unknownBytes, bytes)
        }
    }

    private func saturatingAdd(_ lhs: UInt64, _ rhs: UInt64) -> UInt64 {
        let (value, overflow) = lhs.addingReportingOverflow(rhs)
        return overflow ? UInt64.max : value
    }
}

private enum ApplicationIdentityResolver {
    static func signingIdentifier(from auditToken: Data?) -> String? {
        guard let auditToken, !auditToken.isEmpty else { return nil }
        let attributes = [kSecGuestAttributeAudit as String: auditToken] as CFDictionary
        var runningCode: SecCode?
        guard SecCodeCopyGuestWithAttributes(nil, attributes, SecCSFlags(), &runningCode) == errSecSuccess,
              let runningCode else { return nil }

        var staticCode: SecStaticCode?
        guard SecCodeCopyStaticCode(runningCode, SecCSFlags(), &staticCode) == errSecSuccess,
              let staticCode else { return nil }

        var information: CFDictionary?
        guard SecCodeCopySigningInformation(staticCode, SecCSFlags(), &information) == errSecSuccess,
              let dictionary = information as? [String: Any] else { return nil }
        return dictionary[kSecCodeInfoIdentifier as String] as? String
    }
}

private enum LocalityClassifier {
    static func classify(flow: NEFilterFlow) -> String {
        guard let socket = flow as? NEFilterSocketFlow else { return "unknown" }
        if let endpoint = socket.remoteEndpoint {
            return classify(endpointDescription: String(describing: endpoint))
        }
        if let hostname = socket.remoteHostname {
            return classify(endpointDescription: hostname)
        }
        return "unknown"
    }

    static func classify(endpointDescription raw: String) -> String {
        let value = raw.lowercased()
        if value.contains("localhost") || value.contains("::1") { return "loopback" }

        if let ipv4 = firstIPv4(in: value), let parts = ipv4Octets(ipv4) {
            if parts[0] == 127 { return "loopback" }
            if parts[0] == 10 { return "localNetwork" }
            if parts[0] == 172 && (16...31).contains(parts[1]) { return "localNetwork" }
            if parts[0] == 192 && parts[1] == 168 { return "localNetwork" }
            if parts[0] == 169 && parts[1] == 254 { return "localNetwork" }
            return "external"
        }

        let ipv6 = bracketedIPv6(in: value) ?? (value.contains("::") ? value : nil)
        if let ipv6 {
            if ipv6.contains("::1") { return "loopback" }
            if ipv6.contains("fe8") || ipv6.contains("fe9") || ipv6.contains("fea") || ipv6.contains("feb") || ipv6.contains("fc") || ipv6.contains("fd") { return "localNetwork" }
            return "external"
        }

        // Hostname-only endpoints remain unknown; never perform a DNS lookup only
        // to produce a classification.
        return "unknown"
    }

    private static func firstIPv4(in value: String) -> String? {
        for token in value.split(whereSeparator: { !($0.isNumber || $0 == ".") }) {
            let candidate = String(token)
            if ipv4Octets(candidate) != nil { return candidate }
        }
        return nil
    }

    private static func ipv4Octets(_ value: String) -> [Int]? {
        let parts = value.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 4 else { return nil }
        let values = parts.compactMap { Int($0) }
        guard values.count == 4, values.allSatisfy({ (0...255).contains($0) }) else { return nil }
        return values
    }

    private static func bracketedIPv6(in value: String) -> String? {
        guard let open = value.firstIndex(of: "["), let close = value[open...].firstIndex(of: "]") else { return nil }
        return String(value[value.index(after: open)..<close])
    }
}
