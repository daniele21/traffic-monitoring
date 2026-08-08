import OSLog

extension Logger {
    static let counters = Logger(subsystem: "com.daniele21.trafficmonitoring", category: "counters")
    static let context = Logger(subsystem: "com.daniele21.trafficmonitoring", category: "network-context")
    static let diagnostics = Logger(subsystem: "com.daniele21.trafficmonitoring", category: "diagnostics")
    static let persistence = Logger(subsystem: "com.daniele21.trafficmonitoring", category: "persistence")
}
