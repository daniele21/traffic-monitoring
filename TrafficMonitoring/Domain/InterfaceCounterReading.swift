import Foundation

public struct InterfaceCounterReading: Sendable, Equatable {
    public let interfaceName: String
    public let receivedBytes: UInt64
    public let transmittedBytes: UInt64
    public let isUp: Bool
    public let isRunning: Bool
    public let isLoopback: Bool
    public let linkType: UInt8?
    public let observedAt: Date
    public let monotonicNanos: UInt64

    public init(
        interfaceName: String,
        receivedBytes: UInt64,
        transmittedBytes: UInt64,
        isUp: Bool = true,
        isRunning: Bool = true,
        isLoopback: Bool = false,
        linkType: UInt8? = nil,
        observedAt: Date = Date(),
        monotonicNanos: UInt64
    ) {
        self.interfaceName = interfaceName
        self.receivedBytes = receivedBytes
        self.transmittedBytes = transmittedBytes
        self.isUp = isUp
        self.isRunning = isRunning
        self.isLoopback = isLoopback
        self.linkType = linkType
        self.observedAt = observedAt
        self.monotonicNanos = monotonicNanos
    }
}

public protocol InterfaceCounterReader: Sendable {
    func readCounters() throws -> [InterfaceCounterReading]
}
