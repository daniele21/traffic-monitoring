import NetworkExtension
import OSLog

final class FilterDataProvider: NEFilterDataProvider {
    private let logger = Logger(subsystem: "com.daniele21.trafficmonitoring", category: "advanced-data-provider")

    override func startFilter(completionHandler: @escaping (Error?) -> Void) {
        logger.notice("Experimental Advanced Observability data provider started")
        completionHandler(nil)
    }

    override func stopFilter(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        logger.notice("Experimental data provider stopped: \(String(describing: reason), privacy: .public)")
        completionHandler()
    }

    override func handleNewFlow(_ flow: NEFilterFlow) -> NEFilterNewFlowVerdict {
        let verdict = NEFilterNewFlowVerdict.allow()
        verdict.shouldReport = true
        verdict.statisticsReportFrequency = .low
        return verdict
    }

    override func handle(_ report: NEFilterReport) {
        guard report.event == .statistics else { return }
        let app = report.flow?.sourceAppIdentifier ?? "unknown-application"
        logger.debug("statistics app=\(app, privacy: .public) inbound=\(report.bytesInboundCount, privacy: .public) outbound=\(report.bytesOutboundCount, privacy: .public)")
    }
}
