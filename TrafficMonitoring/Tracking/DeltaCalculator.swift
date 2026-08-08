import Foundation

public struct DeltaValidationConfiguration: Sendable, Equatable {
    /// Deliberately generous default: 400 Gbit/s of aggregate interface traffic.
    public var maximumBytesPerSecond: Double

    public init(maximumBytesPerSecond: Double = 50_000_000_000) {
        self.maximumBytesPerSecond = maximumBytesPerSecond
    }
}

public enum DeltaDiscardReason: Sendable, Equatable {
    case differentInterface
    case nonPositiveElapsedTime
    case counterRegression
    case implausibleRate
}

public enum DeltaCalculationResult: Sendable, Equatable {
    case accepted(TrafficDelta)
    case discarded(DeltaDiscardReason)
}

public struct DeltaCalculator: Sendable {
    public let configuration: DeltaValidationConfiguration

    public init(configuration: DeltaValidationConfiguration = .init()) {
        self.configuration = configuration
    }

    public func calculate(previous: InterfaceCounterReading, current: InterfaceCounterReading) -> DeltaCalculationResult {
        guard previous.interfaceName == current.interfaceName else {
            return .discarded(.differentInterface)
        }
        guard current.monotonicNanos > previous.monotonicNanos else {
            return .discarded(.nonPositiveElapsedTime)
        }
        guard current.receivedBytes >= previous.receivedBytes,
              current.transmittedBytes >= previous.transmittedBytes else {
            return .discarded(.counterRegression)
        }

        let elapsed = Double(current.monotonicNanos - previous.monotonicNanos) / 1_000_000_000
        let rx = current.receivedBytes - previous.receivedBytes
        let tx = current.transmittedBytes - previous.transmittedBytes
        let total = Double(rx) + Double(tx)
        let rate = total / elapsed

        guard rate <= configuration.maximumBytesPerSecond else {
            return .discarded(.implausibleRate)
        }

        return .accepted(
            TrafficDelta(
                interfaceName: current.interfaceName,
                receivedBytes: rx,
                transmittedBytes: tx,
                elapsedSeconds: elapsed
            )
        )
    }
}
