import XCTest
#if SWIFT_PACKAGE
@testable import TrafficMonitoringCore
#else
@testable import TrafficMonitoring
#endif

final class DeltaCalculatorTests: XCTestCase {
    private func reading(
        _ name: String = "en0",
        rx: UInt64,
        tx: UInt64,
        nanos: UInt64
    ) -> InterfaceCounterReading {
        InterfaceCounterReading(
            interfaceName: name,
            receivedBytes: rx,
            transmittedBytes: tx,
            monotonicNanos: nanos
        )
    }

    func testMonotonicCountersProduceExactDelta() {
        let calculator = DeltaCalculator()
        let result = calculator.calculate(
            previous: reading(rx: 1_000, tx: 500, nanos: 1_000_000_000),
            current: reading(rx: 2_500, tx: 900, nanos: 3_000_000_000)
        )

        XCTAssertEqual(
            result,
            .accepted(TrafficDelta(interfaceName: "en0", receivedBytes: 1_500, transmittedBytes: 400, elapsedSeconds: 2))
        )
    }

    func testCounterRegressionIsDiscarded() {
        let result = DeltaCalculator().calculate(
            previous: reading(rx: 2_000, tx: 500, nanos: 1_000_000_000),
            current: reading(rx: 1_999, tx: 600, nanos: 2_000_000_000)
        )
        XCTAssertEqual(result, .discarded(.counterRegression))
    }

    func testTimerJitterUsesActualElapsedTime() {
        let result = DeltaCalculator().calculate(
            previous: reading(rx: 1_000, tx: 1_000, nanos: 1_000_000_000),
            current: reading(rx: 4_000, tx: 2_000, nanos: 3_500_000_000)
        )
        guard case let .accepted(delta) = result else {
            return XCTFail("Expected accepted delta")
        }
        XCTAssertEqual(delta.elapsedSeconds, 2.5, accuracy: 0.0001)
        XCTAssertEqual(delta.downloadBytesPerSecond, 1_200, accuracy: 0.001)
        XCTAssertEqual(delta.uploadBytesPerSecond, 400, accuracy: 0.001)
    }

    func testImplausibleRateIsDiscarded() {
        let calculator = DeltaCalculator(configuration: .init(maximumBytesPerSecond: 100))
        let result = calculator.calculate(
            previous: reading(rx: 0, tx: 0, nanos: 1_000_000_000),
            current: reading(rx: 1_000, tx: 0, nanos: 2_000_000_000)
        )
        XCTAssertEqual(result, .discarded(.implausibleRate))
    }

    func testDifferentInterfacesAreDiscarded() {
        let result = DeltaCalculator().calculate(
            previous: reading("en0", rx: 100, tx: 100, nanos: 1_000_000_000),
            current: reading("en5", rx: 200, tx: 200, nanos: 2_000_000_000)
        )
        XCTAssertEqual(result, .discarded(.differentInterface))
    }

    func testLargeUInt64CountersDoNotOverflowSubtraction() {
        let base = UInt64.max - 10_000
        let result = DeltaCalculator().calculate(
            previous: reading(rx: base, tx: base, nanos: 1_000_000_000),
            current: reading(rx: base + 2_000, tx: base + 3_000, nanos: 2_000_000_000)
        )
        guard case let .accepted(delta) = result else {
            return XCTFail("Expected accepted delta")
        }
        XCTAssertEqual(delta.receivedBytes, 2_000)
        XCTAssertEqual(delta.transmittedBytes, 3_000)
    }
}
