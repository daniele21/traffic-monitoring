import Foundation

public struct LightweightApplicationIdentity: Codable, Equatable, Sendable {
    public let name: String
    public let bundleIdentifier: String?

    public init(name: String, bundleIdentifier: String? = nil) {
        self.name = name
        self.bundleIdentifier = bundleIdentifier
    }

    public var stableKey: String {
        if let bundleIdentifier, !bundleIdentifier.isEmpty {
            return "bundle:\(bundleIdentifier.lowercased())"
        }
        return "name:\(name.lowercased())"
    }
}

public struct LightweightProcessNetworkSample: Identifiable, Codable, Equatable, Sendable {
    public let processName: String
    public let processIdentifier: Int32?
    public let downloadedBytes: UInt64
    public let uploadedBytes: UInt64
    public let observedAt: Date
    public let application: LightweightApplicationIdentity?

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
        observedAt: Date,
        application: LightweightApplicationIdentity? = nil
    ) {
        self.processName = processName
        self.processIdentifier = processIdentifier
        self.downloadedBytes = downloadedBytes
        self.uploadedBytes = uploadedBytes
        self.observedAt = observedAt
        self.application = application
    }
}

public struct LightweightApplicationNetworkSummary: Identifiable, Codable, Equatable, Sendable {
    public let applicationName: String
    public let bundleIdentifier: String?
    public let downloadedBytes: UInt64
    public let uploadedBytes: UInt64
    public let observedAt: Date
    public let processes: [LightweightProcessNetworkSample]

    public var id: String {
        if let bundleIdentifier, !bundleIdentifier.isEmpty {
            return "bundle:\(bundleIdentifier.lowercased())"
        }
        return "name:\(applicationName.lowercased())"
    }

    public var totalBytes: UInt64 {
        let (value, overflow) = downloadedBytes.addingReportingOverflow(uploadedBytes)
        return overflow ? .max : value
    }

    public var processCount: Int { processes.count }

    public init(
        applicationName: String,
        bundleIdentifier: String?,
        downloadedBytes: UInt64,
        uploadedBytes: UInt64,
        observedAt: Date,
        processes: [LightweightProcessNetworkSample]
    ) {
        self.applicationName = applicationName
        self.bundleIdentifier = bundleIdentifier
        self.downloadedBytes = downloadedBytes
        self.uploadedBytes = uploadedBytes
        self.observedAt = observedAt
        self.processes = processes
    }
}

public struct LightweightProcessNameNetworkSummary: Identifiable, Codable, Equatable, Sendable {
    public let processName: String
    public let downloadedBytes: UInt64
    public let uploadedBytes: UInt64
    public let observedAt: Date
    public let processes: [LightweightProcessNetworkSample]

    public var id: String { processName.lowercased() }

    public var totalBytes: UInt64 {
        let (value, overflow) = downloadedBytes.addingReportingOverflow(uploadedBytes)
        return overflow ? .max : value
    }

    public var processCount: Int { processes.count }

    public var applicationNames: [String] {
        Array(Set(processes.compactMap { $0.application?.name })).sorted {
            $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
        }
    }

    public init(
        processName: String,
        downloadedBytes: UInt64,
        uploadedBytes: UInt64,
        observedAt: Date,
        processes: [LightweightProcessNetworkSample]
    ) {
        self.processName = processName
        self.downloadedBytes = downloadedBytes
        self.uploadedBytes = uploadedBytes
        self.observedAt = observedAt
        self.processes = processes
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
