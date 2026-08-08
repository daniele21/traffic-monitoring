import XCTest
#if SWIFT_PACKAGE
@testable import TrafficMonitoringCore
#else
@testable import TrafficMonitoring
#endif

final class UsageAnalyticsAggregatorTests: XCTestCase {
    private let aggregator = UsageAnalyticsAggregator()

    func testSummaryReconcilesWithNetworkRowsAndTrend() {
        let buckets = [
            bucket("a1", network: "wifi:a", name: "Home", hour: 8, download: 1_000, upload: 100),
            bucket("a2", network: "wifi:a", name: "Home", hour: 9, download: 2_000, upload: 200),
            bucket("b1", network: "wifi:b", name: "Phone", hour: 9, download: 3_000, upload: 300)
        ]

        let summary = aggregator.summary(buckets)
        let rows = aggregator.usageByNetwork(buckets)
        let trend = aggregator.timeSeries(buckets, granularity: .hour, calendar: utcCalendar)

        XCTAssertEqual(summary.downloadedBytes, 6_000)
        XCTAssertEqual(summary.uploadedBytes, 600)
        XCTAssertEqual(summary.totalBytes, 6_600)
        XCTAssertEqual(summary.networkCount, 2)
        XCTAssertEqual(rows.reduce(0) { $0 + $1.totalBytes }, summary.totalBytes)
        XCTAssertEqual(trend.reduce(0) { $0 + $1.totalBytes }, summary.totalBytes)
    }

    func testUsageByNetworkRanksLargestFirst() {
        let rows = aggregator.usageByNetwork([
            bucket("small", network: "wifi:a", name: "Home", hour: 8, download: 1_000, upload: 0),
            bucket("large", network: "wifi:b", name: "Phone", hour: 8, download: 5_000, upload: 0)
        ])

        XCTAssertEqual(rows.map(\.networkName), ["Phone", "Home"])
        XCTAssertEqual(rows.first?.totalBytes, 5_000)
    }

    func testHourlyTrendCombinesNetworksIntoSameInterval() {
        let trend = aggregator.timeSeries([
            bucket("a", network: "wifi:a", name: "Home", hour: 10, minute: 5, download: 1_000, upload: 100),
            bucket("b", network: "wifi:b", name: "Phone", hour: 10, minute: 45, download: 2_000, upload: 200)
        ], granularity: .hour, calendar: utcCalendar)

        XCTAssertEqual(trend.count, 1)
        XCTAssertEqual(trend[0].downloadedBytes, 3_000)
        XCTAssertEqual(trend[0].uploadedBytes, 300)
    }

    func testNetworkTrendKeepsNetworksSeparateInsideSameInterval() {
        let trend = aggregator.trendByNetwork([
            bucket("a", network: "wifi:a", name: "Home", hour: 10, download: 1_000, upload: 100),
            bucket("b", network: "wifi:b", name: "Phone", hour: 10, download: 2_000, upload: 200)
        ], granularity: .hour, calendar: utcCalendar)

        XCTAssertEqual(trend.count, 2)
        XCTAssertEqual(Set(trend.map(\.networkName)), Set(["Home", "Phone"]))
        XCTAssertEqual(trend.reduce(0) { $0 + $1.totalBytes }, 3_300)
    }

    private var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func bucket(
        _ key: String,
        network: String,
        name: String,
        hour: Int,
        minute: Int = 0,
        download: UInt64,
        upload: UInt64
    ) -> UsageBucketSnapshot {
        let date = utcCalendar.date(from: DateComponents(
            year: 2026,
            month: 8,
            day: 8,
            hour: hour,
            minute: minute
        ))!

        return UsageBucketSnapshot(
            bucketKey: key,
            identityKey: network,
            networkName: name,
            connectionKind: .wifi,
            interfaceName: "en0",
            startedAt: date,
            endedAt: date.addingTimeInterval(300),
            downloadedBytes: download,
            uploadedBytes: upload,
            isExpensive: name == "Phone",
            isConstrained: false,
            lastObservedAt: date.addingTimeInterval(120)
        )
    }
}
