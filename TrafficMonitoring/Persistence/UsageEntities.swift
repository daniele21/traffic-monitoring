#if os(macOS)
import Foundation
import SwiftData

@Model
final class NetworkProfileEntity {
    @Attribute(.unique) var identityKey: String
    var networkName: String
    var displayAlias: String?
    var connectionKindRaw: String
    var interfaceName: String
    var firstSeenAt: Date
    var lastSeenAt: Date
    var lastKnownExpensive: Bool
    var lastKnownConstrained: Bool

    init(
        identityKey: String,
        networkName: String,
        displayAlias: String? = nil,
        connectionKindRaw: String,
        interfaceName: String,
        firstSeenAt: Date,
        lastSeenAt: Date,
        lastKnownExpensive: Bool,
        lastKnownConstrained: Bool
    ) {
        self.identityKey = identityKey
        self.networkName = networkName
        self.displayAlias = displayAlias
        self.connectionKindRaw = connectionKindRaw
        self.interfaceName = interfaceName
        self.firstSeenAt = firstSeenAt
        self.lastSeenAt = lastSeenAt
        self.lastKnownExpensive = lastKnownExpensive
        self.lastKnownConstrained = lastKnownConstrained
    }
}

@Model
final class UsageBucketEntity {
    @Attribute(.unique) var bucketKey: String
    var identityKey: String
    var networkName: String
    var connectionKindRaw: String
    var interfaceName: String
    var startedAt: Date
    var endedAt: Date
    var downloadedBytes: Int64
    var uploadedBytes: Int64
    var isExpensive: Bool
    var isConstrained: Bool
    var lastObservedAt: Date

    init(
        bucketKey: String,
        identityKey: String,
        networkName: String,
        connectionKindRaw: String,
        interfaceName: String,
        startedAt: Date,
        endedAt: Date,
        downloadedBytes: Int64,
        uploadedBytes: Int64,
        isExpensive: Bool,
        isConstrained: Bool,
        lastObservedAt: Date
    ) {
        self.bucketKey = bucketKey
        self.identityKey = identityKey
        self.networkName = networkName
        self.connectionKindRaw = connectionKindRaw
        self.interfaceName = interfaceName
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.downloadedBytes = downloadedBytes
        self.uploadedBytes = uploadedBytes
        self.isExpensive = isExpensive
        self.isConstrained = isConstrained
        self.lastObservedAt = lastObservedAt
    }
}

@Model
final class EvidenceCoverageEntity {
    @Attribute(.unique) var bucketKey: String
    var startedAt: Date
    var endedAt: Date
    var activeSeconds: Double
    var healthySeconds: Double
    var metadataDegradedSeconds: Double
    var trackingDegradedSeconds: Double
    var unknownNetworkSeconds: Double
    var lastObservedAt: Date

    init(
        bucketKey: String,
        startedAt: Date,
        endedAt: Date,
        activeSeconds: Double,
        healthySeconds: Double,
        metadataDegradedSeconds: Double,
        trackingDegradedSeconds: Double,
        unknownNetworkSeconds: Double,
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
#endif
