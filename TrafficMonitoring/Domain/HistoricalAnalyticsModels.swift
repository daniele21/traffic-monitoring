import Foundation

public struct UsageBucketSnapshot: Identifiable, Sendable, Equatable {
    public let bucketKey: String
    public let identityKey: String
    public let networkName: String
    public let connectionKind: NetworkConnectionKind
    public let interfaceName: String
    public let startedAt: Date
    public let endedAt: Date
    public let downloadedBytes: UInt64
    public let uploadedBytes: UInt64
    public let isExpensive: Bool
    public let isConstrained: Bool
    public let lastObservedAt: Date

    public var id: String { bucketKey }

    public var totalBytes: UInt64 {
        downloadedBytes &+ uploadedBytes
    }

    public init(
        bucketKey: String,
        identityKey: String,
        networkName: String,
        connectionKind: NetworkConnectionKind,
        interfaceName: String,
        startedAt: Date,
        endedAt: Date,
        downloadedBytes: UInt64,
        uploadedBytes: UInt64,
        isExpensive: Bool,
        isConstrained: Bool,
        lastObservedAt: Date
    ) {
        self.bucketKey = bucketKey
        self.identityKey = identityKey
        self.networkName = networkName
        self.connectionKind = connectionKind
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

public struct UsageSummary: Sendable, Equatable {
    public var downloadedBytes: UInt64
    public var uploadedBytes: UInt64
    public var networkCount: Int

    public var totalBytes: UInt64 {
        downloadedBytes &+ uploadedBytes
    }

    public init(downloadedBytes: UInt64 = 0, uploadedBytes: UInt64 = 0, networkCount: Int = 0) {
        self.downloadedBytes = downloadedBytes
        self.uploadedBytes = uploadedBytes
        self.networkCount = networkCount
    }
}

public struct NetworkUsageHistoryRow: Identifiable, Sendable, Equatable {
    public let identityKey: String
    public var networkName: String
    public var connectionKind: NetworkConnectionKind
    public var downloadedBytes: UInt64
    public var uploadedBytes: UInt64
    public var firstSeenAt: Date
    public var lastSeenAt: Date
    public var isExpensive: Bool
    public var isConstrained: Bool

    public var id: String { identityKey }

    public var totalBytes: UInt64 {
        downloadedBytes &+ uploadedBytes
    }

    public init(
        identityKey: String,
        networkName: String,
        connectionKind: NetworkConnectionKind,
        downloadedBytes: UInt64,
        uploadedBytes: UInt64,
        firstSeenAt: Date,
        lastSeenAt: Date,
        isExpensive: Bool,
        isConstrained: Bool = false
    ) {
        self.identityKey = identityKey
        self.networkName = networkName
        self.connectionKind = connectionKind
        self.downloadedBytes = downloadedBytes
        self.uploadedBytes = uploadedBytes
        self.firstSeenAt = firstSeenAt
        self.lastSeenAt = lastSeenAt
        self.isExpensive = isExpensive
        self.isConstrained = isConstrained
    }
}

public enum UsageTimeGranularity: Sendable, Equatable {
    case hour
    case day
}

public struct UsageTrendPoint: Identifiable, Sendable, Equatable {
    public let intervalStart: Date
    public var downloadedBytes: UInt64
    public var uploadedBytes: UInt64

    public var id: Date { intervalStart }

    public var totalBytes: UInt64 {
        downloadedBytes &+ uploadedBytes
    }

    public init(intervalStart: Date, downloadedBytes: UInt64, uploadedBytes: UInt64) {
        self.intervalStart = intervalStart
        self.downloadedBytes = downloadedBytes
        self.uploadedBytes = uploadedBytes
    }
}

public struct NetworkTrendPoint: Identifiable, Sendable, Equatable {
    public let intervalStart: Date
    public let identityKey: String
    public var networkName: String
    public var downloadedBytes: UInt64
    public var uploadedBytes: UInt64

    public var id: String {
        "\(intervalStart.timeIntervalSince1970):\(identityKey)"
    }

    public var totalBytes: UInt64 {
        downloadedBytes &+ uploadedBytes
    }

    public init(
        intervalStart: Date,
        identityKey: String,
        networkName: String,
        downloadedBytes: UInt64,
        uploadedBytes: UInt64
    ) {
        self.intervalStart = intervalStart
        self.identityKey = identityKey
        self.networkName = networkName
        self.downloadedBytes = downloadedBytes
        self.uploadedBytes = uploadedBytes
    }
}
