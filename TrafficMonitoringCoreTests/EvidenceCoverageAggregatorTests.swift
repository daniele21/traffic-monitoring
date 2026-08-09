import XCTest
#if SWIFT_PACKAGE
@testable import TrafficMonitoringCore
#else
@testable import TrafficMonitoring
#endif

final class EvidenceCoverageAggregatorTests: XCTestCase {
    private let aggregator = EvidenceCoverageAggregator()

    func testCoverageSummaryReconcilesObservedAndUnobservedTime() {
        let start = Date(timeIntervalSince1970: 1_786_180_800)
        let snapshots = [
            EvidenceCoverageSnapshot(
                bucketKey: "a",
                startedAt: start,
                endedAt: start.addingTimeInterval(300),
                activeSeconds: 120,
                healthySeconds: 120,
                metadataDegradedSeconds: 0,
                trackingDegradedSeconds: 0,
                unknownNetworkSeconds: 0,
                lastObservedAt: start.addingTimeInterval(120)
            ),
            EvidenceCoverageSnapshot(
                bucketKey: "b",
                startedAt: start.addingTimeInterval(300),
                endedAt: start.addingTimeInterval(600),
                activeSeconds: 180,
                healthySeconds: 180,
                metadataDegradedSeconds: 60,
                trackingDegradedSeconds: 0,
                unknownNetworkSeconds: 0,
                lastObservedAt: start.addingTimeInterval(480)
            )
        ]

        let summary = aggregator.summary(
            snapshots,
            selectedPeriod: DateInterval(start: start, end: start.addingTimeInterval(600))
        )

        XCTAssertEqual(summary.selectedSeconds, 600, accuracy: 0.001)
        XCTAssertEqual(summary.observedSeconds, 300, accuracy: 0.001)
        XCTAssertEqual(summary.unobservedSeconds, 300, accuracy: 0.001)
        XCTAssertEqual(summary.observedRatio, 0.5, accuracy: 0.001)
        XCTAssertEqual(summary.quality, .partiallyIdentified)
    }

    func testObservationGapAloneMakesEvidencePartial() {
        let start = Date(timeIntervalSince1970: 1_786_180_800)
        let snapshot = EvidenceCoverageSnapshot(
            bucketKey: "gap",
            startedAt: start,
            endedAt: start.addingTimeInterval(300),
            activeSeconds: 60,
            healthySeconds: 60,
            metadataDegradedSeconds: 0,
            trackingDegradedSeconds: 0,
            unknownNetworkSeconds: 0,
            lastObservedAt: start.addingTimeInterval(60)
        )

        let summary = aggregator.summary(
            [snapshot],
            selectedPeriod: DateInterval(start: start, end: start.addingTimeInterval(120))
        )

        XCTAssertEqual(summary.unobservedSeconds, 60, accuracy: 0.001)
        XCTAssertEqual(summary.quality, .partiallyIdentified)
    }

    func testTrackingDegradedTakesPrecedence() {
        let start = Date(timeIntervalSince1970: 1_786_180_800)
        let snapshot = EvidenceCoverageSnapshot(
            bucketKey: "degraded",
            startedAt: start,
            endedAt: start.addingTimeInterval(300),
            activeSeconds: 20,
            healthySeconds: 10,
            metadataDegradedSeconds: 5,
            trackingDegradedSeconds: 10,
            unknownNetworkSeconds: 5,
            lastObservedAt: start.addingTimeInterval(20)
        )

        XCTAssertEqual(aggregator.summary([snapshot], selectedPeriod: nil).quality, .trackingDegraded)
    }

    func testUnknownWiFiIdentityIsExplicit() {
        XCTAssertEqual(
            NetworkIdentityQuality.quality(
                identityKey: "wifi:en0:ssid-unavailable",
                connectionKind: .wifi,
                networkName: "Wi-Fi · SSID unavailable"
            ),
            .unknownNetwork
        )
    }

    func testKnownWiFiIdentityIsIdentified() {
        XCTAssertEqual(
            NetworkIdentityQuality.quality(
                identityKey: "wifi:en0:Home",
                connectionKind: .wifi,
                networkName: "Home"
            ),
            .identified
        )
    }
}
