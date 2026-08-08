import Foundation

public struct UsageAnalyticsAggregator: Sendable {
    public init() {}

    public func summary(_ buckets: [UsageBucketSnapshot]) -> UsageSummary {
        var downloaded: UInt64 = 0
        var uploaded: UInt64 = 0
        var identities = Set<String>()

        for bucket in buckets {
            downloaded = saturatedAdd(downloaded, bucket.downloadedBytes)
            uploaded = saturatedAdd(uploaded, bucket.uploadedBytes)
            identities.insert(bucket.identityKey)
        }

        return UsageSummary(
            downloadedBytes: downloaded,
            uploadedBytes: uploaded,
            networkCount: identities.count
        )
    }

    public func usageByNetwork(_ buckets: [UsageBucketSnapshot]) -> [NetworkUsageHistoryRow] {
        var rows: [String: NetworkUsageHistoryRow] = [:]

        for bucket in buckets {
            if var existing = rows[bucket.identityKey] {
                existing.networkName = bucket.networkName
                existing.connectionKind = bucket.connectionKind
                existing.downloadedBytes = saturatedAdd(existing.downloadedBytes, bucket.downloadedBytes)
                existing.uploadedBytes = saturatedAdd(existing.uploadedBytes, bucket.uploadedBytes)
                existing.firstSeenAt = min(existing.firstSeenAt, bucket.startedAt)
                existing.lastSeenAt = max(existing.lastSeenAt, bucket.lastObservedAt)
                existing.isExpensive = existing.isExpensive || bucket.isExpensive
                rows[bucket.identityKey] = existing
            } else {
                rows[bucket.identityKey] = NetworkUsageHistoryRow(
                    identityKey: bucket.identityKey,
                    networkName: bucket.networkName,
                    connectionKind: bucket.connectionKind,
                    downloadedBytes: bucket.downloadedBytes,
                    uploadedBytes: bucket.uploadedBytes,
                    firstSeenAt: bucket.startedAt,
                    lastSeenAt: bucket.lastObservedAt,
                    isExpensive: bucket.isExpensive
                )
            }
        }

        return rows.values.sorted {
            if $0.totalBytes == $1.totalBytes {
                return $0.networkName.localizedCaseInsensitiveCompare($1.networkName) == .orderedAscending
            }
            return $0.totalBytes > $1.totalBytes
        }
    }

    public func timeSeries(
        _ buckets: [UsageBucketSnapshot],
        granularity: UsageTimeGranularity,
        calendar: Calendar = .current
    ) -> [UsageTrendPoint] {
        var points: [Date: UsageTrendPoint] = [:]

        for bucket in buckets {
            let start = intervalStart(for: bucket.startedAt, granularity: granularity, calendar: calendar)
            if var existing = points[start] {
                existing.downloadedBytes = saturatedAdd(existing.downloadedBytes, bucket.downloadedBytes)
                existing.uploadedBytes = saturatedAdd(existing.uploadedBytes, bucket.uploadedBytes)
                points[start] = existing
            } else {
                points[start] = UsageTrendPoint(
                    intervalStart: start,
                    downloadedBytes: bucket.downloadedBytes,
                    uploadedBytes: bucket.uploadedBytes
                )
            }
        }

        return points.values.sorted { $0.intervalStart < $1.intervalStart }
    }

    public func trendByNetwork(
        _ buckets: [UsageBucketSnapshot],
        granularity: UsageTimeGranularity,
        calendar: Calendar = .current
    ) -> [NetworkTrendPoint] {
        struct Key: Hashable {
            let intervalStart: Date
            let identityKey: String
        }

        var points: [Key: NetworkTrendPoint] = [:]

        for bucket in buckets {
            let start = intervalStart(for: bucket.startedAt, granularity: granularity, calendar: calendar)
            let key = Key(intervalStart: start, identityKey: bucket.identityKey)

            if var existing = points[key] {
                existing.networkName = bucket.networkName
                existing.downloadedBytes = saturatedAdd(existing.downloadedBytes, bucket.downloadedBytes)
                existing.uploadedBytes = saturatedAdd(existing.uploadedBytes, bucket.uploadedBytes)
                points[key] = existing
            } else {
                points[key] = NetworkTrendPoint(
                    intervalStart: start,
                    identityKey: bucket.identityKey,
                    networkName: bucket.networkName,
                    downloadedBytes: bucket.downloadedBytes,
                    uploadedBytes: bucket.uploadedBytes
                )
            }
        }

        return points.values.sorted {
            if $0.intervalStart == $1.intervalStart {
                return $0.networkName.localizedCaseInsensitiveCompare($1.networkName) == .orderedAscending
            }
            return $0.intervalStart < $1.intervalStart
        }
    }

    private func intervalStart(
        for date: Date,
        granularity: UsageTimeGranularity,
        calendar: Calendar
    ) -> Date {
        switch granularity {
        case .hour:
            return calendar.dateInterval(of: .hour, for: date)?.start ?? date
        case .day:
            return calendar.startOfDay(for: date)
        }
    }

    private func saturatedAdd(_ lhs: UInt64, _ rhs: UInt64) -> UInt64 {
        let (value, overflow) = lhs.addingReportingOverflow(rhs)
        return overflow ? UInt64.max : value
    }
}
