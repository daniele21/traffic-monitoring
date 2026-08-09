import Foundation

public struct LightweightProcessNetworkSample: Identifiable, Codable, Equatable, Sendable {
    public let processName: String
    public let processIdentifier: Int32?
    public let downloadedBytes: UInt64
    public let uploadedBytes: UInt64
    public let observedAt: Date

    public var totalBytes: UInt64 {
        let (value, overflow) = downloadedBytes.addingReportingOverflow(uploadedBytes)
        return overflow ? .max : value
    }

    public var id: String {
        if let processIdentifier { return "\(processName).\(processIdentifier)" }
        return processName
    }

    public init(
        processName: String,
        processIdentifier: Int32?,
        downloadedBytes: UInt64,
        uploadedBytes: UInt64,
        observedAt: Date
    ) {
        self.processName = processName
        self.processIdentifier = processIdentifier
        self.downloadedBytes = downloadedBytes
        self.uploadedBytes = uploadedBytes
        self.observedAt = observedAt
    }
}

public enum LightweightAppActivityState: String, Codable, Equatable, Sendable {
    case disabled
    case available
    case unavailable
    case failed

    public var title: String {
        switch self {
        case .disabled: "Off"
        case .available: "Available"
        case .unavailable: "Unavailable"
        case .failed: "Needs attention"
        }
    }
}
