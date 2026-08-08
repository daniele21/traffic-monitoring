import Foundation

public enum FlowLocality: String, Codable, CaseIterable, Sendable, Equatable {
    case loopback, localNetwork, external, unknown
    public var title: String {
        switch self { case .loopback: "Loopback"; case .localNetwork: "Local network"; case .external: "External"; case .unknown: "Unknown" }
    }
}

public enum AdvancedObservabilityProviderState: String, Codable, Sendable, Equatable {
    case disabled, providerUnavailable, awaitingApproval, active, degraded
    public var title: String {
        switch self { case .disabled: "Disabled"; case .providerUnavailable: "Provider unavailable"; case .awaitingApproval: "Awaiting approval"; case .active: "Active"; case .degraded: "Degraded" }
    }
}

public enum ByteAccountingCapability: String, Codable, Sendable, Equatable {
    case notValidated, unavailable, validated
    public var title: String {
        switch self { case .notValidated: "Not validated"; case .unavailable: "Unavailable"; case .validated: "Validated" }
    }
}

public struct ApplicationFlowEvidence: Identifiable, Codable, Sendable, Equatable {
    public let id: UUID
    public let observedAt: Date
    public let applicationIdentifier: String?
    public let processIdentifier: String?
    public let locality: FlowLocality
    public let transport: String?
    public let accountedBytes: UInt64?

    public init(id: UUID = UUID(), observedAt: Date, applicationIdentifier: String?, processIdentifier: String? = nil, locality: FlowLocality, transport: String? = nil, accountedBytes: UInt64? = nil) {
        self.id = id; self.observedAt = observedAt; self.applicationIdentifier = applicationIdentifier; self.processIdentifier = processIdentifier; self.locality = locality; self.transport = transport; self.accountedBytes = accountedBytes
    }
}

public struct ApplicationEvidenceSummary: Identifiable, Codable, Sendable, Equatable {
    public let applicationIdentifier: String
    public var loopbackFlows: Int
    public var localNetworkFlows: Int
    public var externalFlows: Int
    public var unknownFlows: Int
    public var loopbackBytes: UInt64
    public var localNetworkBytes: UInt64
    public var externalBytes: UInt64
    public var unknownBytes: UInt64
    public var accountedBytes: UInt64
    public var hasCompleteByteAccounting: Bool
    public var lastObservedAt: Date
    public var id: String { applicationIdentifier }
    public var totalFlows: Int { loopbackFlows + localNetworkFlows + externalFlows + unknownFlows }

    public init(applicationIdentifier: String, loopbackFlows: Int = 0, localNetworkFlows: Int = 0, externalFlows: Int = 0, unknownFlows: Int = 0, loopbackBytes: UInt64 = 0, localNetworkBytes: UInt64 = 0, externalBytes: UInt64 = 0, unknownBytes: UInt64 = 0, accountedBytes: UInt64 = 0, hasCompleteByteAccounting: Bool = true, lastObservedAt: Date) {
        self.applicationIdentifier = applicationIdentifier; self.loopbackFlows = loopbackFlows; self.localNetworkFlows = localNetworkFlows; self.externalFlows = externalFlows; self.unknownFlows = unknownFlows; self.loopbackBytes = loopbackBytes; self.localNetworkBytes = localNetworkBytes; self.externalBytes = externalBytes; self.unknownBytes = unknownBytes; self.accountedBytes = accountedBytes; self.hasCompleteByteAccounting = hasCompleteByteAccounting; self.lastObservedAt = lastObservedAt
    }
}

/// Aggregate-only provider snapshot transported over the Advanced Observability
/// XPC bridge. Optional diagnostic fields preserve decoding compatibility with
/// earlier prototype snapshots and intentionally contain no endpoint/payload data.
public struct AdvancedObservabilitySnapshot: Codable, Sendable, Equatable {
    public let providerState: AdvancedObservabilityProviderState
    public let byteAccounting: ByteAccountingCapability
    public let applications: [ApplicationEvidenceSummary]
    public let lastObservedAt: Date?
    public let generatedAt: Date
    public let protocolVersion: Int?
    public let providerStartedAt: Date?
    public let activeFlowCount: Int?
    public let observedFlowCount: Int?

    public init(
        providerState: AdvancedObservabilityProviderState,
        byteAccounting: ByteAccountingCapability,
        applications: [ApplicationEvidenceSummary],
        lastObservedAt: Date?,
        generatedAt: Date = Date(),
        protocolVersion: Int? = nil,
        providerStartedAt: Date? = nil,
        activeFlowCount: Int? = nil,
        observedFlowCount: Int? = nil
    ) {
        self.providerState = providerState
        self.byteAccounting = byteAccounting
        self.applications = applications
        self.lastObservedAt = lastObservedAt
        self.generatedAt = generatedAt
        self.protocolVersion = protocolVersion
        self.providerStartedAt = providerStartedAt
        self.activeFlowCount = activeFlowCount
        self.observedFlowCount = observedFlowCount
    }
}

public struct ApplicationEvidenceAggregator: Sendable {
    public init() {}
    public func summaries(_ observations: [ApplicationFlowEvidence]) -> [ApplicationEvidenceSummary] {
        var result: [String: ApplicationEvidenceSummary] = [:]
        for observation in observations {
            let app = observation.applicationIdentifier ?? "Unknown application"
            var summary = result[app] ?? ApplicationEvidenceSummary(applicationIdentifier: app, lastObservedAt: observation.observedAt)
            switch observation.locality { case .loopback: summary.loopbackFlows += 1; case .localNetwork: summary.localNetworkFlows += 1; case .external: summary.externalFlows += 1; case .unknown: summary.unknownFlows += 1 }
            if let bytes = observation.accountedBytes {
                summary.accountedBytes = saturatingAdd(summary.accountedBytes, bytes)
                switch observation.locality { case .loopback: summary.loopbackBytes = saturatingAdd(summary.loopbackBytes, bytes); case .localNetwork: summary.localNetworkBytes = saturatingAdd(summary.localNetworkBytes, bytes); case .external: summary.externalBytes = saturatingAdd(summary.externalBytes, bytes); case .unknown: summary.unknownBytes = saturatingAdd(summary.unknownBytes, bytes) }
            } else { summary.hasCompleteByteAccounting = false }
            summary.lastObservedAt = max(summary.lastObservedAt, observation.observedAt)
            result[app] = summary
        }
        return result.values.sorted { $0.totalFlows == $1.totalFlows ? $0.applicationIdentifier.localizedCaseInsensitiveCompare($1.applicationIdentifier) == .orderedAscending : $0.totalFlows > $1.totalFlows }
    }
    private func saturatingAdd(_ lhs: UInt64, _ rhs: UInt64) -> UInt64 { let (v,o)=lhs.addingReportingOverflow(rhs); return o ? .max : v }
}
