import Foundation

public enum NetworkConnectionKind: String, Sendable, Equatable {
    case wifi = "Wi-Fi"
    case wired = "Ethernet"
    case other = "Other"
}

public struct SessionNetworkUsage: Identifiable, Sendable, Equatable {
    public let identityKey: String
    public var networkName: String
    public var connectionKind: NetworkConnectionKind
    public var downloadedBytes: UInt64
    public var uploadedBytes: UInt64
    public var firstSeenAt: Date
    public var lastSeenAt: Date
    public var isExpensive: Bool

    public var id: String { identityKey }

    public var totalBytes: UInt64 {
        downloadedBytes &+ uploadedBytes
    }

    public init(
        identityKey: String,
        networkName: String,
        connectionKind: NetworkConnectionKind,
        downloadedBytes: UInt64 = 0,
        uploadedBytes: UInt64 = 0,
        firstSeenAt: Date,
        lastSeenAt: Date,
        isExpensive: Bool = false
    ) {
        self.identityKey = identityKey
        self.networkName = networkName
        self.connectionKind = connectionKind
        self.downloadedBytes = downloadedBytes
        self.uploadedBytes = uploadedBytes
        self.firstSeenAt = firstSeenAt
        self.lastSeenAt = lastSeenAt
        self.isExpensive = isExpensive
    }
}
