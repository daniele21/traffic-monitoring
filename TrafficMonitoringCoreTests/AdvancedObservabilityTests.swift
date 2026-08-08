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

    func testApplicationEvidenceAggregatorKeepsLocalityBytesAndMissingAccountingExplicit() throws {
        let now = Date(timeIntervalSince1970: 1_786_180_800)
        let observations = [
            ApplicationFlowEvidence(observedAt: now, applicationIdentifier: "com.example.local", locality: .localNetwork, accountedBytes: 100),
            ApplicationFlowEvidence(observedAt: now.addingTimeInterval(1), applicationIdentifier: "com.example.local", locality: .external, accountedBytes: 25),
            ApplicationFlowEvidence(observedAt: now.addingTimeInterval(2), applicationIdentifier: "com.example.local", locality: .unknown, accountedBytes: nil),
            ApplicationFlowEvidence(observedAt: now.addingTimeInterval(3), applicationIdentifier: nil, locality: .unknown, accountedBytes: nil)
        ]
        let rows = ApplicationEvidenceAggregator().summaries(observations)
        let app = try XCTUnwrap(rows.first { $0.applicationIdentifier == "com.example.local" })
        XCTAssertEqual(app.localNetworkFlows, 1)
        XCTAssertEqual(app.externalFlows, 1)
        XCTAssertEqual(app.unknownFlows, 1)
        XCTAssertEqual(app.localNetworkBytes, 100)
        XCTAssertEqual(app.externalBytes, 25)
        XCTAssertEqual(app.accountedBytes, 125)
        XCTAssertFalse(app.hasCompleteByteAccounting)
    }

    func testAdvancedSnapshotRoundTripsThroughBridgeJSONContract() throws {
        let now = Date(timeIntervalSince1970: 1_786_180_800)
        let snapshot = AdvancedObservabilitySnapshot(providerState: .active, byteAccounting: .notValidated, applications: [ApplicationEvidenceSummary(applicationIdentifier: "com.example.app", localNetworkFlows: 2, externalFlows: 1, localNetworkBytes: 100, externalBytes: 50, accountedBytes: 150, hasCompleteByteAccounting: false, lastObservedAt: now)], lastObservedAt: now, generatedAt: now)
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        XCTAssertEqual(try decoder.decode(AdvancedObservabilitySnapshot.self, from: encoder.encode(snapshot)), snapshot)
    }
}
