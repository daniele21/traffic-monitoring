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
        // On macOS `sourceAppIdentifier` is unavailable. B0 tests whether an audit
        // token is exposed instead; resolving that token into an app identity remains
        // a separate capability and privacy gate.
        let hasSourceAppAuditToken = flow.sourceAppAuditToken != nil
        logger.debug("new flow sourceAppAuditToken=\(hasSourceAppAuditToken, privacy: .public)")

        let verdict = NEFilterNewFlowVerdict.allow()
        verdict.shouldReport = true
        verdict.statisticsReportFrequency = .low
        return verdict
    }

    override func handle(_ report: NEFilterReport) {
        guard report.event == .statistics else { return }
        let hasSourceAppAuditToken = report.flow?.sourceAppAuditToken != nil
        logger.debug("statistics sourceAppAuditToken=\(hasSourceAppAuditToken, privacy: .public) inbound=\(report.bytesInboundCount, privacy: .public) outbound=\(report.bytesOutboundCount, privacy: .public)")
    }
}
