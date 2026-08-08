import Foundation

public struct SessionUsageAccumulator: Sendable, Equatable {
    private var usageByIdentity: [String: SessionNetworkUsage] = [:]

    public init() {}

    public mutating func record(
        identityKey: String,
        networkName: String,
        connectionKind: NetworkConnectionKind,
        isExpensive: Bool,
        observedAt: Date,
        delta: TrafficDelta
    ) {
        guard delta.totalBytes > 0 else { return }

        if var existing = usageByIdentity[identityKey] {
            existing.networkName = networkName
            existing.connectionKind = connectionKind
            existing.downloadedBytes = saturatedAdd(existing.downloadedBytes, delta.receivedBytes)
            existing.uploadedBytes = saturatedAdd(existing.uploadedBytes, delta.transmittedBytes)
            existing.lastSeenAt = max(existing.lastSeenAt, observedAt)
            existing.isExpensive = existing.isExpensive || isExpensive
            usageByIdentity[identityKey] = existing
        } else {
            usageByIdentity[identityKey] = SessionNetworkUsage(
                identityKey: identityKey,
                networkName: networkName,
                connectionKind: connectionKind,
                downloadedBytes: delta.receivedBytes,
                uploadedBytes: delta.transmittedBytes,
                firstSeenAt: observedAt,
                lastSeenAt: observedAt,
                isExpensive: isExpensive
            )
        }
    }

    public var networks: [SessionNetworkUsage] {
        usageByIdentity.values.sorted {
            if $0.totalBytes == $1.totalBytes {
                return $0.networkName.localizedCaseInsensitiveCompare($1.networkName) == .orderedAscending
            }
            return $0.totalBytes > $1.totalBytes
        }
    }

    public var downloadedBytes: UInt64 {
        usageByIdentity.values.reduce(0) { saturatedAdd($0, $1.downloadedBytes) }
    }

    public var uploadedBytes: UInt64 {
        usageByIdentity.values.reduce(0) { saturatedAdd($0, $1.uploadedBytes) }
    }

    public var totalBytes: UInt64 {
        saturatedAdd(downloadedBytes, uploadedBytes)
    }

    public mutating func reset() {
        usageByIdentity.removeAll()
    }

    private func saturatedAdd(_ lhs: UInt64, _ rhs: UInt64) -> UInt64 {
        let (value, overflow) = lhs.addingReportingOverflow(rhs)
        return overflow ? UInt64.max : value
    }
}
