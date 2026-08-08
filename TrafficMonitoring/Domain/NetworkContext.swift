import Foundation

public enum NetworkKind: String, Sendable, Codable, CaseIterable {
    case wifi
    case wired
    case otherPhysical
    case unknown
}

public struct NetworkIdentity: Hashable, Sendable, Codable {
    public let kind: NetworkKind
    public let interfaceName: String
    public let discriminator: String

    public init(kind: NetworkKind, interfaceName: String, discriminator: String) {
        self.kind = kind
        self.interfaceName = interfaceName
        self.discriminator = discriminator
    }

    public var stableKey: String {
        "\(kind.rawValue):\(interfaceName):\(discriminator)"
    }
}

public enum PathStatus: String, Sendable, Codable {
    case satisfied
    case unsatisfied
    case requiresConnection
    case unknown
}

public struct NetworkContext: Sendable, Equatable {
    public let identity: NetworkIdentity
    public let displayName: String
    public let ssid: String?
    public let pathStatus: PathStatus
    public let isExpensive: Bool
    public let isConstrained: Bool
    public let observedAt: Date

    public init(
        identity: NetworkIdentity,
        displayName: String,
        ssid: String? = nil,
        pathStatus: PathStatus = .unknown,
        isExpensive: Bool = false,
        isConstrained: Bool = false,
        observedAt: Date = Date()
    ) {
        self.identity = identity
        self.displayName = displayName
        self.ssid = ssid
        self.pathStatus = pathStatus
        self.isExpensive = isExpensive
        self.isConstrained = isConstrained
        self.observedAt = observedAt
    }
}

public struct NetworkContextSnapshot: Sendable, Equatable {
    public let pathStatus: PathStatus
    public let isExpensive: Bool
    public let isConstrained: Bool
    /// CoreWLAN interface names are available independently from SSID access.
    public let wifiInterfaceNames: Set<String>
    /// SSIDs are optional enrichment and may be empty when Location is denied.
    public let wifiSSIDByInterface: [String: String]
    public let observedAt: Date

    public init(
        pathStatus: PathStatus,
        isExpensive: Bool,
        isConstrained: Bool,
        wifiInterfaceNames: Set<String>,
        wifiSSIDByInterface: [String: String],
        observedAt: Date = Date()
    ) {
        self.pathStatus = pathStatus
        self.isExpensive = isExpensive
        self.isConstrained = isConstrained
        self.wifiInterfaceNames = wifiInterfaceNames
        self.wifiSSIDByInterface = wifiSSIDByInterface
        self.observedAt = observedAt
    }
}

public protocol NetworkContextProviding: Sendable {
    func currentSnapshot() async -> NetworkContextSnapshot
}
