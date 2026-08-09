import Foundation

public struct EvidenceExportCoverage: Codable, Sendable, Equatable {
    public let quality: EvidenceQuality
    public let selectedSeconds: TimeInterval
    public let observedSeconds: TimeInterval
    public let healthySeconds: TimeInterval
    public let metadataDegradedSeconds: TimeInterval
    public let trackingDegradedSeconds: TimeInterval
    public let unknownNetworkSeconds: TimeInterval
    public let unobservedSeconds: TimeInterval

    public init(summary: EvidenceCoverageSummary) {
        quality = summary.quality
        selectedSeconds = summary.selectedSeconds
        observedSeconds = summary.observedSeconds
        healthySeconds = summary.healthySeconds
        metadataDegradedSeconds = summary.metadataDegradedSeconds
        trackingDegradedSeconds = summary.trackingDegradedSeconds
        unknownNetworkSeconds = summary.unknownNetworkSeconds
        unobservedSeconds = summary.unobservedSeconds
    }
}

public struct EvidenceExportNetwork: Codable, Sendable, Equatable {
    public let identityKey: String
    public let displayName: String
    public let connectionKind: String
    public let downloadedBytes: UInt64
    public let uploadedBytes: UInt64
    public let totalBytes: UInt64
    public let isExpensive: Bool
    public let isConstrained: Bool
    public let identityQuality: EvidenceQuality
    public let firstObservedAt: Date
    public let lastObservedAt: Date

    public init(row: NetworkUsageHistoryRow) {
        identityKey = row.identityKey
        displayName = row.networkName
        connectionKind = row.connectionKind.rawValue
        downloadedBytes = row.downloadedBytes
        uploadedBytes = row.uploadedBytes
        totalBytes = row.totalBytes
        isExpensive = row.isExpensive
        isConstrained = row.isConstrained
        identityQuality = NetworkIdentityQuality.quality(
            identityKey: row.identityKey,
            connectionKind: row.connectionKind,
            networkName: row.networkName
        )
        firstObservedAt = row.firstSeenAt
        lastObservedAt = row.lastSeenAt
    }
}

public struct EvidenceExportTotals: Codable, Sendable, Equatable {
    public let downloadedBytes: UInt64
    public let uploadedBytes: UInt64
    public let totalBytes: UInt64
    public let networkCount: Int

    public init(summary: UsageSummary) {
        downloadedBytes = summary.downloadedBytes
        uploadedBytes = summary.uploadedBytes
        totalBytes = summary.totalBytes
        networkCount = summary.networkCount
    }
}

public struct EvidenceExportDocument: Codable, Sendable, Equatable {
    public let schemaVersion: Int
    public let generatedAt: Date
    public let appVersion: String
    public let measurementScope: String
    public let periodStart: Date?
    public let periodEnd: Date?
    public let totals: EvidenceExportTotals
    public let coverage: EvidenceExportCoverage
    public let networks: [EvidenceExportNetwork]

    public init(
        schemaVersion: Int,
        generatedAt: Date,
        appVersion: String,
        measurementScope: String,
        periodStart: Date?,
        periodEnd: Date?,
        totals: EvidenceExportTotals,
        coverage: EvidenceExportCoverage,
        networks: [EvidenceExportNetwork]
    ) {
        self.schemaVersion = schemaVersion
        self.generatedAt = generatedAt
        self.appVersion = appVersion
        self.measurementScope = measurementScope
        self.periodStart = periodStart
        self.periodEnd = periodEnd
        self.totals = totals
        self.coverage = coverage
        self.networks = networks
    }
}
