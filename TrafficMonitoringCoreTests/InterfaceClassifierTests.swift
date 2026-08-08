import XCTest
#if SWIFT_PACKAGE
@testable import TrafficMonitoringCore
#else
@testable import TrafficMonitoring
#endif

final class InterfaceClassifierTests: XCTestCase {
    private let classifier = InterfaceClassifier()

    private func reading(_ name: String, up: Bool = true, loopback: Bool = false) -> InterfaceCounterReading {
        InterfaceCounterReading(
            interfaceName: name,
            receivedBytes: 0,
            transmittedBytes: 0,
            isUp: up,
            isRunning: up,
            isLoopback: loopback,
            monotonicNanos: 1
        )
    }

    func testCoreWLANMappedInterfaceIsWiFi() {
        XCTAssertEqual(classifier.classify(reading("en0"), wifiInterfaceNames: ["en0"]), .wifi)
    }

    func testOtherENInterfaceFallsBackToWired() {
        XCTAssertEqual(classifier.classify(reading("en5"), wifiInterfaceNames: []), .wired)
    }

    func testVPNIsExcluded() {
        XCTAssertEqual(
            classifier.classify(reading("utun4"), wifiInterfaceNames: []),
            .excluded(reason: "virtual-or-system")
        )
    }

    func testLoopbackIsExcluded() {
        XCTAssertEqual(
            classifier.classify(reading("lo0", loopback: true), wifiInterfaceNames: []),
            .excluded(reason: "loopback")
        )
    }

    func testDownInterfaceIsExcluded() {
        XCTAssertEqual(
            classifier.classify(reading("en0", up: false), wifiInterfaceNames: ["en0"]),
            .excluded(reason: "interface-down")
        )
    }
}
