import XCTest
#if SWIFT_PACKAGE
@testable import TrafficMonitoringCore
#else
@testable import TrafficMonitoring
#endif

final class LightweightApplicationActivityAggregatorTests: XCTestCase {
    func testGroupsMultipleProcessesUnderSameResolvedApplication() throws {
        let now = Date(timeIntervalSince1970: 1_786_180_800)
        let app = LightweightApplicationIdentity(name: "Antigravity IDE", bundleIdentifier: "com.example.antigravity")
        let samples = [
            LightweightProcessNetworkSample(
                processName: "Antigravity IDE",
                processIdentifier: 80_236,
                downloadedBytes: 7_800_000,
                uploadedBytes: 448_000_000,
                observedAt: now,
                application: app
            ),
            LightweightProcessNetworkSample(
                processName: "language_server",
                processIdentifier: 45_816,
                downloadedBytes: 373_200_000,
                uploadedBytes: 14_200_000,
                observedAt: now,
                application: app
            )
        ]

        let summaries = LightweightApplicationActivityAggregator().aggregate(samples)
        let summary = try XCTUnwrap(summaries.first)

        XCTAssertEqual(summaries.count, 1)
        XCTAssertEqual(summary.applicationName, "Antigravity IDE")
        XCTAssertEqual(summary.bundleIdentifier, "com.example.antigravity")
        XCTAssertEqual(summary.processCount, 2)
        XCTAssertEqual(summary.downloadedBytes, 381_000_000)
        XCTAssertEqual(summary.uploadedBytes, 462_200_000)
        XCTAssertEqual(summary.totalBytes, 843_200_000)
        XCTAssertEqual(summary.processes.map(\.processName), ["Antigravity IDE", "language_server"])
    }

    func testUnresolvedProcessesWithSameNameStillAggregateWithoutInventingApplicationIdentity() throws {
        let now = Date(timeIntervalSince1970: 1_786_180_800)
        let samples = [
            LightweightProcessNetworkSample(
                processName: "mDNSResponder",
                processIdentifier: 434,
                downloadedBytes: 100,
                uploadedBytes: 200,
                observedAt: now
            ),
            LightweightProcessNetworkSample(
                processName: "mDNSResponder",
                processIdentifier: 435,
                downloadedBytes: 300,
                uploadedBytes: 400,
                observedAt: now
            )
        ]

        let summary = try XCTUnwrap(LightweightApplicationActivityAggregator().aggregate(samples).first)
        XCTAssertEqual(summary.applicationName, "mDNSResponder")
        XCTAssertNil(summary.bundleIdentifier)
        XCTAssertEqual(summary.processCount, 2)
        XCTAssertEqual(summary.totalBytes, 1_000)
    }

    func testApplicationsSortByTotalBytesDescending() {
        let now = Date(timeIntervalSince1970: 1_786_180_800)
        let samples = [
            LightweightProcessNetworkSample(
                processName: "Small",
                processIdentifier: 1,
                downloadedBytes: 10,
                uploadedBytes: 20,
                observedAt: now,
                application: LightweightApplicationIdentity(name: "Small App", bundleIdentifier: "com.example.small")
            ),
            LightweightProcessNetworkSample(
                processName: "Large",
                processIdentifier: 2,
                downloadedBytes: 100,
                uploadedBytes: 200,
                observedAt: now,
                application: LightweightApplicationIdentity(name: "Large App", bundleIdentifier: "com.example.large")
            )
        ]

        let summaries = LightweightApplicationActivityAggregator().aggregate(samples)
        XCTAssertEqual(summaries.map(\.applicationName), ["Large App", "Small App"])
    }

    func testAggregationSaturatesInsteadOfOverflowing() throws {
        let now = Date(timeIntervalSince1970: 1_786_180_800)
        let app = LightweightApplicationIdentity(name: "Large App", bundleIdentifier: "com.example.large")
        let samples = [
            LightweightProcessNetworkSample(
                processName: "Large A",
                processIdentifier: 1,
                downloadedBytes: UInt64.max,
                uploadedBytes: 0,
                observedAt: now,
                application: app
            ),
            LightweightProcessNetworkSample(
                processName: "Large B",
                processIdentifier: 2,
                downloadedBytes: 1,
                uploadedBytes: UInt64.max,
                observedAt: now,
                application: app
            )
        ]

        let summary = try XCTUnwrap(LightweightApplicationActivityAggregator().aggregate(samples).first)
        XCTAssertEqual(summary.downloadedBytes, UInt64.max)
        XCTAssertEqual(summary.uploadedBytes, UInt64.max)
        XCTAssertEqual(summary.totalBytes, UInt64.max)
    }

    func testProcessNameAggregationCombinesSameNameAcrossPIDs() throws {
        let now = Date(timeIntervalSince1970: 1_786_180_800)
        let app = LightweightApplicationIdentity(name: "Antigravity IDE", bundleIdentifier: "com.example.antigravity")
        let samples = [
            LightweightProcessNetworkSample(
                processName: "language_server",
                processIdentifier: 45_816,
                downloadedBytes: 373_200_000,
                uploadedBytes: 14_200_000,
                observedAt: now,
                application: app
            ),
            LightweightProcessNetworkSample(
                processName: "language_server",
                processIdentifier: 80_449,
                downloadedBytes: 87_500_000,
                uploadedBytes: 6_800_000,
                observedAt: now,
                application: app
            ),
            LightweightProcessNetworkSample(
                processName: "language_server",
                processIdentifier: 30_285,
                downloadedBytes: 32_000_000,
                uploadedBytes: 840_000,
                observedAt: now,
                application: app
            )
        ]

        let summary = try XCTUnwrap(LightweightProcessNameActivityAggregator().aggregate(samples).first)
        XCTAssertEqual(summary.processName, "language_server")
        XCTAssertEqual(summary.processCount, 3)
        XCTAssertEqual(summary.downloadedBytes, 492_700_000)
        XCTAssertEqual(summary.uploadedBytes, 21_840_000)
        XCTAssertEqual(summary.totalBytes, 514_540_000)
        XCTAssertEqual(summary.applicationNames, ["Antigravity IDE"])
    }

    func testProcessNameAggregationCanSpanApplicationsWithoutMergingApplicationIdentity() throws {
        let now = Date(timeIntervalSince1970: 1_786_180_800)
        let samples = [
            LightweightProcessNetworkSample(
                processName: "Electron",
                processIdentifier: 100,
                downloadedBytes: 10,
                uploadedBytes: 20,
                observedAt: now,
                application: LightweightApplicationIdentity(name: "App A", bundleIdentifier: "com.example.a")
            ),
            LightweightProcessNetworkSample(
                processName: "Electron",
                processIdentifier: 200,
                downloadedBytes: 30,
                uploadedBytes: 40,
                observedAt: now,
                application: LightweightApplicationIdentity(name: "App B", bundleIdentifier: "com.example.b")
            )
        ]

        let summary = try XCTUnwrap(LightweightProcessNameActivityAggregator().aggregate(samples).first)
        XCTAssertEqual(summary.processCount, 2)
        XCTAssertEqual(summary.applicationNames, ["App A", "App B"])
        XCTAssertEqual(summary.totalBytes, 100)
    }
}
