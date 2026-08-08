import Foundation

public struct EvidenceExportService: Sendable {
    public static let schemaVersion = 1
    public static let measurementScope = "Physical network-interface usage observed by Traffic Monitoring. Totals can include local-network traffic and are not exact ISP/carrier billing data."

    private let aggregator = UsageAnalyticsAggregator()

    public init() {}

    public func makeDocument(
        usage: [UsageBucketSnapshot],
        coverage: EvidenceCoverageSummary,
        period: DateInterval?,
        appVersion: String,
        generatedAt: Date = Date()
    ) -> EvidenceExportDocument {
        let summary = aggregator.summary(usage)
        let rows = aggregator.usageByNetwork(usage)
        let effectivePeriod = resolvedPeriod(usage: usage, coverage: coverage, requested: period)

        return EvidenceExportDocument(
            schemaVersion: Self.schemaVersion,
            generatedAt: generatedAt,
            appVersion: appVersion,
            measurementScope: Self.measurementScope,
            periodStart: effectivePeriod?.start,
            periodEnd: effectivePeriod?.end,
            totals: EvidenceExportTotals(summary: summary),
            coverage: EvidenceExportCoverage(summary: coverage),
            networks: rows.map(EvidenceExportNetwork.init(row:))
        )
    }

    public func jsonData(_ document: EvidenceExportDocument) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(document)
    }

    public func jsonString(_ document: EvidenceExportDocument) throws -> String {
        let data = try jsonData(document)
        guard let string = String(data: data, encoding: .utf8) else {
            throw EncodingError.invalidValue(
                document,
                EncodingError.Context(codingPath: [], debugDescription: "Could not create UTF-8 JSON output.")
            )
        }
        return string
    }

    public func csvString(_ document: EvidenceExportDocument) -> String {
        var lines: [String] = []
        lines.append([
            "schema_version",
            "period_start",
            "period_end",
            "app_version",
            "evidence_quality",
            "observed_seconds",
            "selected_seconds",
            "network_identity",
            "network_name",
            "connection_kind",
            "identity_quality",
            "downloaded_bytes",
            "uploaded_bytes",
            "total_bytes",
            "is_expensive",
            "is_constrained",
            "first_observed_at",
            "last_observed_at"
        ].joined(separator: ","))

        let formatter = ISO8601DateFormatter()
        let periodStart = document.periodStart.map(formatter.string(from:)) ?? ""
        let periodEnd = document.periodEnd.map(formatter.string(from:)) ?? ""

        for network in document.networks {
            lines.append([
                String(document.schemaVersion),
                csv(periodStart),
                csv(periodEnd),
                csv(document.appVersion),
                document.coverage.quality.rawValue,
                seconds(document.coverage.observedSeconds),
                seconds(document.coverage.selectedSeconds),
                csv(network.identityKey),
                csv(network.displayName),
                csv(network.connectionKind),
                network.identityQuality.rawValue,
                String(network.downloadedBytes),
                String(network.uploadedBytes),
                String(network.totalBytes),
                network.isExpensive ? "true" : "false",
                network.isConstrained ? "true" : "false",
                formatter.string(from: network.firstObservedAt),
                formatter.string(from: network.lastObservedAt)
            ].joined(separator: ","))
        }

        if document.networks.isEmpty {
            lines.append([
                String(document.schemaVersion),
                csv(periodStart),
                csv(periodEnd),
                csv(document.appVersion),
                document.coverage.quality.rawValue,
                seconds(document.coverage.observedSeconds),
                seconds(document.coverage.selectedSeconds),
                "", "", "", "", "0", "0", "0", "false", "false", "", ""
            ].joined(separator: ","))
        }

        return lines.joined(separator: "\n") + "\n"
    }

    private func resolvedPeriod(
        usage: [UsageBucketSnapshot],
        coverage: EvidenceCoverageSummary,
        requested: DateInterval?
    ) -> DateInterval? {
        if let requested { return requested }

        let usageStart = usage.map(\.startedAt).min()
        let usageEnd = usage.map(\.lastObservedAt).max()
        let start = [usageStart, coverage.firstObservedAt].compactMap { $0 }.min()
        let end = [usageEnd, coverage.lastObservedAt].compactMap { $0 }.max()
        guard let start, let end, end >= start else { return nil }
        return DateInterval(start: start, end: end)
    }

    private func seconds(_ value: TimeInterval) -> String {
        String(format: "%.3f", max(0, value))
    }

    private func csv(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return value
    }
}
