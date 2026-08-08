import Foundation

struct DiagnosticInterfaceRow: Identifiable, Equatable {
    let id: String
    let interfaceName: String
    let classification: String
    let rawReceivedBytes: UInt64
    let rawTransmittedBytes: UInt64
    let deltaReceivedBytes: UInt64
    let deltaTransmittedBytes: UInt64
    let downloadBytesPerSecond: Double
    let uploadBytesPerSecond: Double
    let networkName: String
    let isExpensive: Bool
    let isConstrained: Bool
    let isIncluded: Bool
}
