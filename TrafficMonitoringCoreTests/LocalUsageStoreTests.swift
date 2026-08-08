#if os(macOS) && !SWIFT_PACKAGE
import XCTest
@testable import TrafficMonitoring

@MainActor
final class LocalUsageStoreTests: XCTestCase {
    func testPendingAndPersistedTotalsReconcileAcrossCheckpoints() throws {
        let store = try LocalUsageStore(inMemory: true, checkpointInterval: 15, bucketInterval: 300)
        let observedAt = Date(timeIntervalSince1970: 1_786_180_800)

        store.record(
            identityKey: "wifi:en0:Home",
            networkName: "Home",
            connectionKind: .wifi,
            interfaceName: "en0",
            isExpensive: false,
            isConstrained: false,
            observedAt: observedAt,
            delta: TrafficDelta(interfaceName: "en0", receivedBytes: 1_000, transmittedBytes: 200, elapsedSeconds: 2)
        )

        XCTAssertEqual(try total(store), 1_200)

        try store.flush(now: observedAt.addingTimeInterval(15))
        XCTAssertEqual(try total(store), 1_200)

        store.record(
            identityKey: "wifi:en0:Home",
            networkName: "Home",
            connectionKind: .wifi,
            interfaceName: "en0",
            isExpensive: false,
            isConstrained: false,
            observedAt: observedAt.addingTimeInterval(30),
            delta: TrafficDelta(interfaceName: "en0", receivedBytes: 500, transmittedBytes: 100, elapsedSeconds: 2)
        )

        XCTAssertEqual(try total(store), 1_800)

        try store.flush(now: observedAt.addingTimeInterval(45))
        XCTAssertEqual(try total(store), 1_800)
    }

    func testDifferentNetworksRemainSeparate() throws {
        let store = try LocalUsageStore(inMemory: true)
        let observedAt = Date(timeIntervalSince1970: 1_786_180_800)

        record(store, identity: "wifi:en0:Home", name: "Home", bytes: 1_000, at: observedAt)
        record(store, identity: "wifi:en0:Phone", name: "Phone", bytes: 2_000, at: observedAt)
        try store.flush()

        let rows = UsageAnalyticsAggregator().usageByNetwork(try store.snapshots(in: nil))
        XCTAssertEqual(rows.count, 2)
        XCTAssertEqual(rows.map(\.networkName), ["Phone", "Home"])
    }

    private func total(_ store: LocalUsageStore) throws -> UInt64 {
        UsageAnalyticsAggregator().summary(try store.snapshots(in: nil)).totalBytes
    }

    private func record(
        _ store: LocalUsageStore,
        identity: String,
        name: String,
        bytes: UInt64,
        at date: Date
    ) {
        store.record(
            identityKey: identity,
            networkName: name,
            connectionKind: .wifi,
            interfaceName: "en0",
            isExpensive: name == "Phone",
            isConstrained: false,
            observedAt: date,
            delta: TrafficDelta(interfaceName: "en0", receivedBytes: bytes, transmittedBytes: 0, elapsedSeconds: 2)
        )
    }
}
#endif
