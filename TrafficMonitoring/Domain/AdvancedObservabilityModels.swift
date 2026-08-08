import Foundation

public enum FlowLocality: String, Codable, CaseIterable, Sendable, Equatable {
    case loopback
    case localNetwork
    case external
    case unknown

    public var title: String {
        switch self {
        case .loopback: "Loopback"
        case .localNetwork: "Local network"
        case .external: "External"
        case .unknown: "Unknown"
        }
    }
}

public enum AdvancedObservabilityProviderState: String, Codable, Sendable, Equatable {
    case disabled
    case providerUnavailable
    case awaitingApproval
    case active
    case degraded

    public var title: String {
        switch self {
        case .disabled: "Disabled"
        case .providerUnavailable: "Provider unavailable"
        case .awaitingApproval: "Awaiting approval"
        case .active: "Active"
        case .degraded: "Degraded"
        }
    }
}

public enum ByteAccountingCapability: String, Codable, Sendable, Equatable {
    case notValidated
    case unavailable
    case validated

    public var title: String {
        switch self {
        case .notValidated: "Not validated"
        case .unavailable: "Unavailable"
        case .validated: "Validated"
        }
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

    public init(
        id: UUID = UUID(),
        observedAt: Date,
        applicationIdentifier: String?,
        processIdentifier: String? = nil,
        locality: FlowLocality,
        transport: String? = nil,
        accountedBytes: UInt64? = nil
    ) {
        self.id = id
        self.observedAt = observedAt
        self.applicationIdentifier = applicationIdentifier
        self.processIdentifier = processIdentifier
        self.locality = locality
        self.transport = transport
        self.accountedBytes = accountedBytes
    }
}

public struct ApplicationEvidenceSummary: Identifiable, Sendable, Equatable {
    public let applicationIdentifier: String
    public var loopbackFlows: Int
    public var localNetworkFlows: Int
    public var externalFlows: Int
    public var unknownFlows: Int
    public var accountedBytes: UInt64
    public var hasCompleteByteAccounting: Bool
    public var lastObservedAt: Date

    public var id: String { applicationIdentifier }
    public var totalFlows: Int { loopbackFlows + localNetworkFlows + externalFlows + unknownFlows }

    public init(
        applicationIdentifier: String,
        loopbackFlows: Int = 0,
        localNetworkFlows: Int = 0,
        externalFlows: Int = 0,
        unknownFlows: Int = 0,
        accountedBytes: UInt64 = 0,
        hasCompleteByteAccounting: Bool = true,
        lastObservedAt: Date
    ) {
        self.applicationIdentifier = applicationIdentifier
        self.loopbackFlows = loopbackFlows
        self.localNetworkFlows = localNetworkFlows
        self.externalFlows = externalFlows
        self.unknownFlows = unknownFlows
        self.accountedBytes = accountedBytes
        self.hasCompleteByteAccounting = hasCompleteByteAccounting
        self.lastObservedAt = lastObservedAt
    }
}

public struct AdvancedObservabilitySnapshot: Sendable, Equatable {
    public let providerState: AdvancedObservabilityProviderState
    public let byteAccounting: ByteAccountingCapability
    public let applications: [ApplicationEvidenceSummary]
    public let lastObservedAt: Date?

    public init(
        providerState: AdvancedObservabilityProviderState,
        byteAccounting: ByteAccountingCapability,
        applications: [ApplicationEvidenceSummary],
        lastObservedAt: Date?
    ) {
        self.providerState = providerState
        self.byteAccounting = byteAccounting
        self.applications = applications
        self.lastObservedAt = lastObservedAt
    }
}

public struct ApplicationEvidenceAggregator: Sendable {
    public init() {}

    public func summaries(_ observations: [ApplicationFlowEvidence]) -> [ApplicationEvidenceSummary] {
        var result: [String: ApplicationEvidenceSummary] = [:]

        for observation in observations {
            let app = observation.applicationIdentifier ?? "Unknown application"
            var summary = result[app] ?? ApplicationEvidenceSummary(
                applicationIdentifier: app,
                lastObservedAt: observation.observedAt
            )

            switch observation.locality {
            case .loopback: summary.loopbackFlows += 1
            case .localNetwork: summary.localNetworkFlows += 1
            case .external: summary.externalFlows += 1
            case .unknown: summary.unknownFlows += 1
            }

            if let bytes = observation.accountedBytes {
                let (sum, overflow) = summary.accountedBytes.addingReportingOverflow(bytes)
                summary.accountedBytes = overflow ? UInt64.max : sum
            } else {
                summary.hasCompleteByteAccounting = false
            }

            summary.lastObservedAt = max(summary.lastObservedAt, observation.observedAt)
            result[app] = summary
        }

        return result.values.sorted {
            if $0.totalFlows == $1.totalFlows {
                return $0.applicationIdentifier.localizedCaseInsensitiveCompare($1.applicationIdentifier) == .orderedAscending
            }
            return $0.totalFlows > $1.totalFlows
        }
    }
}
