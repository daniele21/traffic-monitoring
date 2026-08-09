import XCTest
#if SWIFT_PACKAGE
@testable import TrafficMonitoringCore
#else
@testable import TrafficMonitoring
#endif

final class EvidenceExportServiceTests: XCTestCase {
    private let service = EvidenceExportService()

    func testJSONDocumentReconcilesWithUsageTotals() throws {
        let start = Date(timeIntervalSince1970: 1_786_180_800)
        let usage = [
            bucket("home", identity: "wifi:en0:Home", name: "Home", start: start, download: 1_000, upload: 100, expensive: false),
            bucket("phone", identity: "wifi:en0:Phone", name: "Phone", start: start.addingTimeInterval(300), download: 2_000, upload: 200, expensive: true)
        ]
        let coverage = EvidenceCoverageSummary(
            selectedSeconds: 600,
            observedSeconds: 540,
            healthySeconds: 540,
            metadataDegradedSeconds: 0,
            trackingDegradedSeconds: 0,
            unknownNetworkSeconds: 0,
            firstObservedAt: start,
            lastObservedAt: start.addingTimeInterval(540)
        )

        let document = service.makeDocument(
            usage: usage,
            coverage: coverage,
            period: DateInterval(start: start, end: start.addingTimeInterval(600)),
            appVersion: "0.2.0",
            generatedAt: start
        )

        XCTAssertEqual(document.schemaVersion, 1)
        XCTAssertEqual(document.totals.downloadedBytes, 3_000)
        XCTAssertEqual(document.totals.uploadedBytes, 300)
        XCTAssertEqual(document.totals.totalBytes, 3_300)
        XCTAssertEqual(document.networks.reduce(0) { $0 + $1.totalBytes }, document.totals.totalBytes)
        XCTAssertEqual(document.coverage.observedSeconds, 540, accuracy: 0.001)

        let data = try service.jsonData(document)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(EvidenceExportDocument.self, from: data)
        XCTAssertEqual(decoded, document)
    }

    func testCSVContainsVersionCoverageAndNetworkTotals() {
        let start = Date(timeIntervalSince1970: 1_786_180_800)
        let document = service.makeDocument(
            usage: [bucket("home", identity: "wifi:en0:Home", name: "Home, Main", start: start, download: 500, upload: 50, expensive: false)],
            coverage: EvidenceCoverageSummary(selectedSeconds: 60, observedSeconds: 50, healthySeconds: 50),
            period: DateInterval(start: start, end: start.addingTimeInterval(60)),
            appVersion: "0.2.0",
            generatedAt: start
        )

        let csv = service.csvString(document)
        XCTAssertTrue(csv.contains("schema_version"))
        XCTAssertTrue(csv.contains("evidence_quality"))
        XCTAssertTrue(csv.contains("\"Home, Main\""))
        XCTAssertTrue(csv.contains(",500,50,550,"))
    }

    private func bucket(
        _ key: String,
        identity: String,
        name: String,
        start: Date,
        download: UInt64,
        upload: UInt64,
        expensive: Bool
    ) -> UsageBucketSnapshot {
        UsageBucketSnapshot(
            bucketKey: key,
            identityKey: identity,
            networkName: name,
            connectionKind: .wifi,
            interfaceName: "en0",
            startedAt: start,
            endedAt: start.addingTimeInterval(300),
            downloadedBytes: download,
            uploadedBytes: upload,
            isExpensive: expensive,
            isConstrained: false,
            lastObservedAt: start.addingTimeInterval(120)
        )
    }
}
