import Foundation

public struct TrafficDelta: Sendable, Equatable {
    public let interfaceName: String
    public let receivedBytes: UInt64
    public let transmittedBytes: UInt64
    public let elapsedSeconds: Double

    public init(interfaceName: String, receivedBytes: UInt64, transmittedBytes: UInt64, elapsedSeconds: Double) {
        self.interfaceName = interfaceName
        self.receivedBytes = receivedBytes
        self.transmittedBytes = transmittedBytes
        self.elapsedSeconds = elapsedSeconds
    }

    public var totalBytes: UInt64 {
        receivedBytes &+ transmittedBytes
    }

    public var downloadBytesPerSecond: Double {
        elapsedSeconds > 0 ? Double(receivedBytes) / elapsedSeconds : 0
    }

    public var uploadBytesPerSecond: Double {
        elapsedSeconds > 0 ? Double(transmittedBytes) / elapsedSeconds : 0
    }
}
