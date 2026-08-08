import Foundation
import Network
import NetworkExtension
import OSLog

final class FilterControlProvider: NEFilterControlProvider {
    private let logger = Logger(subsystem: "com.daniele21.trafficmonitoring", category: "advanced-control-provider")
    private let store = AggregateBridgeStore()

    override func startFilter(completionHandler: @escaping (Error?) -> Void) {
        logger.notice("Experimental Advanced Observability control provider started")
        completionHandler(nil)
    }

    override func stopFilter(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        logger.notice("Experimental control provider stopped: \(String(describing: reason), privacy: .public)")
        completionHandler()
    }

    override func handle(_ report: NEFilterReport) {
        guard let flow = report.flow else { return }
        store.record(
            flowIdentifier: String(describing: flow.identifier),
            applicationIdentifier: flow.sourceAppIdentifier ?? "Unknown application",
            locality: LocalityClassifier.classify(flow: flow),
            inboundBytes: max(0, report.bytesInboundCount),
            outboundBytes: max(0, report.bytesOutboundCount),
            observedAt: Date()
        )
    }
}

private enum Locality: String, Codable { case loopback, localNetwork, external, unknown }

private enum LocalityClassifier {
    static func classify(flow: NEFilterFlow) -> Locality {
        guard let socket = flow as? NEFilterSocketFlow,
              let endpoint = socket.remoteEndpoint else { return .unknown }

        let host: String
        switch endpoint {
        case let .hostPort(value, _): host = String(describing: value)
        default: return .unknown
        }
        return classify(host: host)
    }

    static func classify(host raw: String) -> Locality {
        var host = raw.lowercased()
        if host.hasPrefix("[") && host.contains("]") { host = host.trimmingCharacters(in: CharacterSet(charactersIn: "[]")) }
        if host == "localhost" || host == "::1" || host.hasPrefix("127.") { return .loopback }

        let parts = host.split(separator: ".", omittingEmptySubsequences: false).compactMap { Int($0) }
        if parts.count == 4, parts.allSatisfy({ (0...255).contains($0) }) {
            if parts[0] == 10 { return .localNetwork }
            if parts[0] == 172 && (16...31).contains(parts[1]) { return .localNetwork }
            if parts[0] == 192 && parts[1] == 168 { return .localNetwork }
            if parts[0] == 169 && parts[1] == 254 { return .localNetwork }
            return .external
        }

        if host.hasPrefix("fe8") || host.hasPrefix("fe9") || host.hasPrefix("fea") || host.hasPrefix("feb") || host.hasPrefix("fc") || host.hasPrefix("fd") { return .localNetwork }
        if host.contains(":") { return .external }
        return .unknown
    }
}

private struct AppAggregate: Codable {
    let applicationIdentifier: String
    var loopbackFlows = 0
    var localNetworkFlows = 0
    var externalFlows = 0
    var unknownFlows = 0
    var loopbackBytes: UInt64 = 0
    var localNetworkBytes: UInt64 = 0
    var externalBytes: UInt64 = 0
    var unknownBytes: UInt64 = 0
    var accountedBytes: UInt64 = 0
    var hasCompleteByteAccounting = false
    var lastObservedAt: Date
}

private struct BridgeSnapshot: Codable {
    let providerState: String
    let byteAccounting: String
    let applications: [AppAggregate]
    let lastObservedAt: Date?
    let generatedAt: Date
}

private final class AggregateBridgeStore {
    private static let appGroup = "group.com.daniele21.trafficmonitoring"
    private static let fileName = "advanced-observability-snapshot.json"
    private struct FlowState { var totalBytes: UInt64; let locality: Locality; let applicationIdentifier: String }

    private let queue = DispatchQueue(label: "com.daniele21.trafficmonitoring.advanced-aggregate")
    private var applications: [String: AppAggregate] = [:]
    private var flows: [String: FlowState] = [:]

    func record(flowIdentifier: String, applicationIdentifier: String, locality: Locality, inboundBytes: Int, outboundBytes: Int, observedAt: Date) {
        queue.sync {
            let total = UInt64(inboundBytes) &+ UInt64(outboundBytes)
            let previous = flows[flowIdentifier]
            let delta = previous.map { total >= $0.totalBytes ? total - $0.totalBytes : total } ?? total
            var app = applications[applicationIdentifier] ?? AppAggregate(applicationIdentifier: applicationIdentifier, lastObservedAt: observedAt)

            if previous == nil {
                switch locality { case .loopback: app.loopbackFlows += 1; case .localNetwork: app.localNetworkFlows += 1; case .external: app.externalFlows += 1; case .unknown: app.unknownFlows += 1 }
            }
            app.accountedBytes = saturatingAdd(app.accountedBytes, delta)
            switch locality { case .loopback: app.loopbackBytes = saturatingAdd(app.loopbackBytes, delta); case .localNetwork: app.localNetworkBytes = saturatingAdd(app.localNetworkBytes, delta); case .external: app.externalBytes = saturatingAdd(app.externalBytes, delta); case .unknown: app.unknownBytes = saturatingAdd(app.unknownBytes, delta) }
            app.lastObservedAt = max(app.lastObservedAt, observedAt)
            applications[applicationIdentifier] = app
            flows[flowIdentifier] = FlowState(totalBytes: total, locality: locality, applicationIdentifier: applicationIdentifier)
            persist(now: observedAt)
        }
    }

    private func persist(now: Date) {
        guard let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Self.appGroup) else { return }
        let snapshot = BridgeSnapshot(providerState: "active", byteAccounting: "notValidated", applications: applications.values.sorted { $0.applicationIdentifier < $1.applicationIdentifier }, lastObservedAt: applications.values.map(\.lastObservedAt).max(), generatedAt: now)
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601; encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(snapshot) else { return }
        try? data.write(to: container.appendingPathComponent(Self.fileName), options: .atomic)
    }

    private func saturatingAdd(_ lhs: UInt64, _ rhs: UInt64) -> UInt64 {
        let (value, overflow) = lhs.addingReportingOverflow(rhs)
        return overflow ? UInt64.max : value
    }
}
