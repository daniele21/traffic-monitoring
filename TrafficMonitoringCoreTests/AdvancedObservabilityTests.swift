import XCTest
#if SWIFT_PACKAGE
@testable import TrafficMonitoringCore
#else
@testable import TrafficMonitoring
#endif

final class AdvancedObservabilityTests: XCTestCase {
    func testLocalityClassifierKeepsUnknownHostnamesExplicit() {
        let classifier = IPLocalityClassifier()
        XCTAssertEqual(classifier.classify(host: "127.0.0.1"), .loopback)
        XCTAssertEqual(classifier.classify(host: "::1"), .loopback)
        XCTAssertEqual(classifier.classify(host: "10.0.0.10"), .localNetwork)
        XCTAssertEqual(classifier.classify(host: "172.20.1.2"), .localNetwork)
        XCTAssertEqual(classifier.classify(host: "192.168.1.10"), .localNetwork)
        XCTAssertEqual(classifier.classify(host: "fe80::1"), .localNetwork)
        XCTAssertEqual(classifier.classify(host: "fd12::1"), .localNetwork)
        XCTAssertEqual(classifier.classify(host: "8.8.8.8"), .external)
        XCTAssertEqual(classifier.classify(host: "example.com"), .unknown)
        XCTAssertEqual(classifier.classify(host: nil), .unknown)
    }

    func testApplicationEvidenceAggregatorKeepsUnknownAndMissingBytesExplicit() {
        let now = Date(timeIntervalSince1970: 1_786_180_800)
        let observations = [
            ApplicationFlowEvidence(observedAt: now, applicationIdentifier: "com.example.local", locality: .localNetwork, accountedBytes: 100),
            ApplicationFlowEvidence(observedAt: now.addingTimeInterval(1), applicationIdentifier: "com.example.local", locality: .external, accountedBytes: nil),
            ApplicationFlowEvidence(observedAt: now.addingTimeInterval(2), applicationIdentifier: nil, locality: .unknown, accountedBytes: nil)
        ]

        let rows = ApplicationEvidenceAggregator().summaries(observations)
        XCTAssertEqual(rows.count, 2)

        let app = try! XCTUnwrap(rows.first { $0.applicationIdentifier == "com.example.local" })
        XCTAssertEqual(app.localNetworkFlows, 1)
        XCTAssertEqual(app.externalFlows, 1)
        XCTAssertEqual(app.accountedBytes, 100)
        XCTAssertFalse(app.hasCompleteByteAccounting)

        let unknown = try! XCTUnwrap(rows.first { $0.applicationIdentifier == "Unknown application" })
        XCTAssertEqual(unknown.unknownFlows, 1)
        XCTAssertFalse(unknown.hasCompleteByteAccounting)
    }
}
