import Foundation

public enum InterfaceClassification: Sendable, Equatable {
    case wifi
    case wired
    case otherPhysical
    case excluded(reason: String)
}

public struct InterfaceClassifier: Sendable {
    public init() {}

    public func classify(_ reading: InterfaceCounterReading, wifiInterfaceNames: Set<String>) -> InterfaceClassification {
        let name = reading.interfaceName.lowercased()

        guard reading.isUp else { return .excluded(reason: "interface-down") }
        guard !reading.isLoopback, name != "lo0" else { return .excluded(reason: "loopback") }

        let excludedPrefixes = ["utun", "awdl", "llw", "gif", "stf", "bridge", "ap", "anpi"]
        if excludedPrefixes.contains(where: { name.hasPrefix($0) }) {
            return .excluded(reason: "virtual-or-system")
        }

        if wifiInterfaceNames.contains(reading.interfaceName) {
            return .wifi
        }

        if name.hasPrefix("en") {
            return .wired
        }

        return .otherPhysical
    }
}
