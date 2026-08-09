import Foundation

public struct LightweightApplicationActivityAggregator: Sendable {
    public init() {}

    public func aggregate(_ samples: [LightweightProcessNetworkSample]) -> [LightweightApplicationNetworkSummary] {
        struct Accumulator {
            var name: String
            var bundleIdentifier: String?
            var downloadedBytes: UInt64 = 0
            var uploadedBytes: UInt64 = 0
            var observedAt: Date
            var processes: [LightweightProcessNetworkSample] = []
        }

        var grouped: [String: Accumulator] = [:]

        for sample in samples {
            let application = sample.application
            let name = application?.name ?? sample.processName
            let bundleIdentifier = application?.bundleIdentifier
            let key: String
            if let application {
                key = application.stableKey
            } else {
                key = "process:\(sample.processName.lowercased())"
            }

            var accumulator = grouped[key] ?? Accumulator(
                name: name,
                bundleIdentifier: bundleIdentifier,
                observedAt: sample.observedAt
            )
            accumulator.downloadedBytes = saturatingAdd(accumulator.downloadedBytes, sample.downloadedBytes)
            accumulator.uploadedBytes = saturatingAdd(accumulator.uploadedBytes, sample.uploadedBytes)
            accumulator.observedAt = max(accumulator.observedAt, sample.observedAt)
            accumulator.processes.append(sample)
            grouped[key] = accumulator
        }

        return grouped.values.map { accumulator in
            LightweightApplicationNetworkSummary(
                applicationName: accumulator.name,
                bundleIdentifier: accumulator.bundleIdentifier,
                downloadedBytes: accumulator.downloadedBytes,
                uploadedBytes: accumulator.uploadedBytes,
                observedAt: accumulator.observedAt,
                processes: accumulator.processes.sorted(by: processOrdering)
            )
        }
        .sorted(by: applicationOrdering)
    }

    private func saturatingAdd(_ lhs: UInt64, _ rhs: UInt64) -> UInt64 {
        let (value, overflow) = lhs.addingReportingOverflow(rhs)
        return overflow ? .max : value
    }

    private func processOrdering(_ lhs: LightweightProcessNetworkSample, _ rhs: LightweightProcessNetworkSample) -> Bool {
        if lhs.totalBytes == rhs.totalBytes {
            return lhs.processName.localizedCaseInsensitiveCompare(rhs.processName) == .orderedAscending
        }
        return lhs.totalBytes > rhs.totalBytes
    }

    private func applicationOrdering(_ lhs: LightweightApplicationNetworkSummary, _ rhs: LightweightApplicationNetworkSummary) -> Bool {
        if lhs.totalBytes == rhs.totalBytes {
            return lhs.applicationName.localizedCaseInsensitiveCompare(rhs.applicationName) == .orderedAscending
        }
        return lhs.totalBytes > rhs.totalBytes
    }
}

public struct LightweightProcessNameActivityAggregator: Sendable {
    public init() {}

    public func aggregate(_ samples: [LightweightProcessNetworkSample]) -> [LightweightProcessNameNetworkSummary] {
        struct Accumulator {
            var name: String
            var downloadedBytes: UInt64 = 0
            var uploadedBytes: UInt64 = 0
            var observedAt: Date
            var processes: [LightweightProcessNetworkSample] = []
        }

        var grouped: [String: Accumulator] = [:]

        for sample in samples {
            let key = sample.processName.lowercased()
            var accumulator = grouped[key] ?? Accumulator(
                name: sample.processName,
                observedAt: sample.observedAt
            )
            accumulator.downloadedBytes = saturatingAdd(accumulator.downloadedBytes, sample.downloadedBytes)
            accumulator.uploadedBytes = saturatingAdd(accumulator.uploadedBytes, sample.uploadedBytes)
            accumulator.observedAt = max(accumulator.observedAt, sample.observedAt)
            accumulator.processes.append(sample)
            grouped[key] = accumulator
        }

        return grouped.values.map { accumulator in
            LightweightProcessNameNetworkSummary(
                processName: accumulator.name,
                downloadedBytes: accumulator.downloadedBytes,
                uploadedBytes: accumulator.uploadedBytes,
                observedAt: accumulator.observedAt,
                processes: accumulator.processes.sorted(by: processOrdering)
            )
        }
        .sorted(by: processNameOrdering)
    }

    private func saturatingAdd(_ lhs: UInt64, _ rhs: UInt64) -> UInt64 {
        let (value, overflow) = lhs.addingReportingOverflow(rhs)
        return overflow ? .max : value
    }

    private func processOrdering(_ lhs: LightweightProcessNetworkSample, _ rhs: LightweightProcessNetworkSample) -> Bool {
        if lhs.totalBytes == rhs.totalBytes {
            return (lhs.processIdentifier ?? 0) < (rhs.processIdentifier ?? 0)
        }
        return lhs.totalBytes > rhs.totalBytes
    }

    private func processNameOrdering(_ lhs: LightweightProcessNameNetworkSummary, _ rhs: LightweightProcessNameNetworkSummary) -> Bool {
        if lhs.totalBytes == rhs.totalBytes {
            return lhs.processName.localizedCaseInsensitiveCompare(rhs.processName) == .orderedAscending
        }
        return lhs.totalBytes > rhs.totalBytes
    }
}
