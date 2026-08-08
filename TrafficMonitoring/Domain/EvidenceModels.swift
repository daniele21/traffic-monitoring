import Foundation

public enum EvidenceQuality: String, Codable, CaseIterable, Sendable, Equatable {
    case identified
    case partiallyIdentified
    case unknownNetwork
    case trackingDegraded

    public var title: String {
        switch self {
        case .identified: "Identified"
        case .partiallyIdentified: "Partially identified"
        case .unknownNetwork: "Unknown network"
        case .trackingDegraded: "Tracking degraded"
        }
    }

    public var explanation: String {
        switch self {
        case .identified:
            "Observed usage is associated with identified network contexts and the selected interval has no known observation gaps."
        case .partiallyIdentified:
            "Some of the selected period was not observed or some measured usage could not be tied to a fully identified network context."
        case .unknownNetwork:
            "Some Wi-Fi or network usage was measured without a reliable network name or identity."
        case .trackingDegraded:
            "Part of the selected period had a counter, persistence, or observation problem."
        }
    }
}

public struct EvidenceCoverageSnapshot: Identifiable, Sendable, Equatable {
    public let bucketKey: String
    public let startedAt: Date
    public let endedAt: Date
    public let activeSeconds: TimeInterval
    public let healthySeconds: TimeInterval
    public let metadataDegradedSeconds: TimeInterval
    public let trackingDegradedSeconds: TimeInterval
    public let unknownNetworkSeconds: TimeInterval
    public let lastObservedAt: Date

    public var id: String { bucketKey }

    public init(
        bucketKey: String,
        startedAt: Date,
        endedAt: Date,
        activeSeconds: TimeInterval,
        healthySeconds: TimeInterval,
        metadataDegradedSeconds: TimeInterval,
        trackingDegradedSeconds: TimeInterval,
        unknownNetworkSeconds: TimeInterval,
        lastObservedAt: Date
    ) {
        self.bucketKey = bucketKey
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.activeSeconds = activeSeconds
        self.healthySeconds = healthySeconds
        self.metadataDegradedSeconds = metadataDegradedSeconds
        self.trackingDegradedSeconds = trackingDegradedSeconds
        self.unknownNetworkSeconds = unknownNetworkSeconds
        self.lastObservedAt = lastObservedAt
    }
}

public struct EvidenceCoverageSummary: Sendable, Equatable {
    public var selectedSeconds: TimeInterval
    public var observedSeconds: TimeInterval
    public var healthySeconds: TimeInterval
    public var metadataDegradedSeconds: TimeInterval
    public var trackingDegradedSeconds: TimeInterval
    public var unknownNetworkSeconds: TimeInterval
    public var firstObservedAt: Date?
    public var lastObservedAt: Date?

    public var unobservedSeconds: TimeInterval {
        max(0, selectedSeconds - observedSeconds)
    }

    public var observedRatio: Double {
        guard selectedSeconds > 0 else { return observedSeconds > 0 ? 1 : 0 }
        return min(1, max(0, observedSeconds / selectedSeconds))
    }

    public var quality: EvidenceQuality {
        if trackingDegradedSeconds > 0 { return .trackingDegraded }
        if unknownNetworkSeconds > 0 { return .unknownNetwork }
        if metadataDegradedSeconds > 0 || unobservedSeconds > 1 { return .partiallyIdentified }
        return .identified
    }

    public init(
        selectedSeconds: TimeInterval = 0,
        observedSeconds: TimeInterval = 0,
        healthySeconds: TimeInterval = 0,
        metadataDegradedSeconds: TimeInterval = 0,
        trackingDegradedSeconds: TimeInterval = 0,
        unknownNetworkSeconds: TimeInterval = 0,
        firstObservedAt: Date? = nil,
        lastObservedAt: Date? = nil
    ) {
        self.selectedSeconds = selectedSeconds
        self.observedSeconds = observedSeconds
        self.healthySeconds = healthySeconds
        self.metadataDegradedSeconds = metadataDegradedSeconds
        self.trackingDegradedSeconds = trackingDegradedSeconds
        self.unknownNetworkSeconds = unknownNetworkSeconds
        self.firstObservedAt = firstObservedAt
        self.lastObservedAt = lastObservedAt
    }
}

public struct EvidenceCoverageAggregator: Sendable {
    public init() {}

    public func summary(
        _ snapshots: [EvidenceCoverageSnapshot],
        selectedPeriod: DateInterval?
    ) -> EvidenceCoverageSummary {
        guard !snapshots.isEmpty else {
            return EvidenceCoverageSummary(
                selectedSeconds: selectedPeriod?.duration ?? 0
            )
        }

        let first = snapshots.map(\.startedAt).min()
        let last = snapshots.map(\.lastObservedAt).max()
        let effectiveStart = selectedPeriod?.start ?? first
        let effectiveEnd = selectedPeriod?.end ?? last
        let selectedSeconds: TimeInterval
        if let effectiveStart, let effectiveEnd {
            selectedSeconds = max(0, effectiveEnd.timeIntervalSince(effectiveStart))
        } else {
            selectedSeconds = 0
        }

        return EvidenceCoverageSummary(
            selectedSeconds: selectedSeconds,
            observedSeconds: snapshots.reduce(0) { $0 + max(0, $1.activeSeconds) },
            healthySeconds: snapshots.reduce(0) { $0 + max(0, $1.healthySeconds) },
            metadataDegradedSeconds: snapshots.reduce(0) { $0 + max(0, $1.metadataDegradedSeconds) },
            trackingDegradedSeconds: snapshots.reduce(0) { $0 + max(0, $1.trackingDegradedSeconds) },
            unknownNetworkSeconds: snapshots.reduce(0) { $0 + max(0, $1.unknownNetworkSeconds) },
            firstObservedAt: first,
            lastObservedAt: last
        )
    }
}

public enum NetworkIdentityQuality {
    public static func quality(
        identityKey: String,
        connectionKind: NetworkConnectionKind,
        networkName: String
    ) -> EvidenceQuality {
        if connectionKind == .wifi,
           identityKey.contains("ssid-unavailable") || networkName.localizedCaseInsensitiveContains("SSID unavailable") {
            return .unknownNetwork
        }

        if identityKey.contains("unknown-network") || connectionKind == .other {
            return .partiallyIdentified
        }

        return .identified
    }
}
