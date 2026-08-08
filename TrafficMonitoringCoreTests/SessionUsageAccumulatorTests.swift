import XCTest
#if SWIFT_PACKAGE
@testable import TrafficMonitoringCore
#else
@testable import TrafficMonitoring
#endif

final class SessionUsageAccumulatorTests: XCTestCase {
    func testAccumulatesUsageForSameNetwork() {
        var accumulator = SessionUsageAccumulator()
        let first = Date(timeIntervalSince1970: 100)
        let second = Date(timeIntervalSince1970: 110)

        accumulator.record(
            identityKey: "wifi:en0:Home",
            networkName: "Home",
            connectionKind: .wifi,
            isExpensive: false,
            observedAt: first,
            delta: TrafficDelta(interfaceName: "en0", receivedBytes: 1_000, transmittedBytes: 200, elapsedSeconds: 2)
        )
        accumulator.record(
            identityKey: "wifi:en0:Home",
            networkName: "Home",
            connectionKind: .wifi,
            isExpensive: false,
            observedAt: second,
            delta: TrafficDelta(interfaceName: "en0", receivedBytes: 3_000, transmittedBytes: 800, elapsedSeconds: 2)
        )

        XCTAssertEqual(accumulator.networks.count, 1)
        XCTAssertEqual(accumulator.networks[0].downloadedBytes, 4_000)
        XCTAssertEqual(accumulator.networks[0].uploadedBytes, 1_000)
        XCTAssertEqual(accumulator.networks[0].totalBytes, 5_000)
        XCTAssertEqual(accumulator.networks[0].firstSeenAt, first)
        XCTAssertEqual(accumulator.networks[0].lastSeenAt, second)
    }

    func testKeepsDifferentNetworksSeparatedAndRanksByUsage() {
        var accumulator = SessionUsageAccumulator()
        let now = Date(timeIntervalSince1970: 100)

        accumulator.record(
            identityKey: "wifi:en0:Office",
            networkName: "Office",
            connectionKind: .wifi,
            isExpensive: false,
            observedAt: now,
            delta: TrafficDelta(interfaceName: "en0", receivedBytes: 500, transmittedBytes: 100, elapsedSeconds: 2)
        )
        accumulator.record(
            identityKey: "wifi:en0:iPhone",
            networkName: "iPhone",
            connectionKind: .wifi,
            isExpensive: true,
            observedAt: now,
            delta: TrafficDelta(interfaceName: "en0", receivedBytes: 2_000, transmittedBytes: 500, elapsedSeconds: 2)
        )

        XCTAssertEqual(accumulator.networks.map(\.networkName), ["iPhone", "Office"])
        XCTAssertEqual(accumulator.totalBytes, 3_100)
        XCTAssertTrue(accumulator.networks[0].isExpensive)
    }

    func testZeroDeltaDoesNotCreateNetworkEntry() {
        var accumulator = SessionUsageAccumulator()

        accumulator.record(
            identityKey: "wifi:en0:Home",
            networkName: "Home",
            connectionKind: .wifi,
            isExpensive: false,
            observedAt: Date(),
            delta: TrafficDelta(interfaceName: "en0", receivedBytes: 0, transmittedBytes: 0, elapsedSeconds: 2)
        )

        XCTAssertTrue(accumulator.networks.isEmpty)
        XCTAssertEqual(accumulator.totalBytes, 0)
    }

    func testResetClearsAllSessionUsage() {
        var accumulator = SessionUsageAccumulator()
        accumulator.record(
            identityKey: "wired:en5:unknown-network",
            networkName: "Ethernet · en5",
            connectionKind: .wired,
            isExpensive: false,
            observedAt: Date(),
            delta: TrafficDelta(interfaceName: "en5", receivedBytes: 1_000, transmittedBytes: 1_000, elapsedSeconds: 2)
        )

        accumulator.reset()

        XCTAssertTrue(accumulator.networks.isEmpty)
        XCTAssertEqual(accumulator.downloadedBytes, 0)
        XCTAssertEqual(accumulator.uploadedBytes, 0)
    }
}
