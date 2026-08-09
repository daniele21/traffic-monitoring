import XCTest
#if SWIFT_PACKAGE
@testable import TrafficMonitoringCore
#else
@testable import TrafficMonitoring
#endif

final class NettopProcessCSVParserTests: XCTestCase {
    func testParsesRunnerSampleAndKeepsPIDSeparateFromName() throws {
        let csv = """
        ,bytes_in,bytes_out,
        launchd.1,0,0,
        mDNSResponder.172,64132,61276,
        Runner.Worker.13744,42130,131434,
        """
        let now = Date(timeIntervalSince1970: 1_786_180_800)
        let rows = NettopProcessCSVParser().parse(csv, observedAt: now)

        XCTAssertEqual(rows.count, 3)
        let runner = try XCTUnwrap(rows.first { $0.processName == "Runner.Worker" })
        XCTAssertEqual(runner.processIdentifier, 13_744)
        XCTAssertEqual(runner.downloadedBytes, 42_130)
        XCTAssertEqual(runner.uploadedBytes, 131_434)
        XCTAssertEqual(runner.totalBytes, 173_564)
        XCTAssertEqual(runner.observedAt, now)
    }

    func testSortsByTotalBytesDescending() {
        let csv = """
        ,bytes_in,bytes_out,
        Small.1,10,20,
        Large.2,100,200,
        """
        let rows = NettopProcessCSVParser().parse(csv)
        XCTAssertEqual(rows.map(\.processName), ["Large", "Small"])
    }

    func testMalformedRowsRemainUnobservableRatherThanInvented() {
        let csv = """
        ,bytes_in,bytes_out,
        MissingBytes.2,,12,
        BadNumber.3,abc,4,
        NameWithoutPID,5,6,
        """
        let rows = NettopProcessCSVParser().parse(csv)
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows.first?.processName, "NameWithoutPID")
        XCTAssertNil(rows.first?.processIdentifier)
    }

    func testQuotedCSVFieldsAreHandled() throws {
        let csv = """
        ,bytes_in,bytes_out,
        "Process, Helper.99",12,34,
        """
        let row = try XCTUnwrap(NettopProcessCSVParser().parse(csv).first)
        XCTAssertEqual(row.processName, "Process, Helper")
        XCTAssertEqual(row.processIdentifier, 99)
    }
}
