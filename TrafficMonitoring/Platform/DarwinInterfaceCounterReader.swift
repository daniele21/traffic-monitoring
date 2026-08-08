#if os(macOS)
import Darwin
import Dispatch
import Foundation

struct InterfaceCounterReadError: LocalizedError {
    let code: Int32

    var errorDescription: String? {
        String(cString: strerror(code))
    }
}

final class DarwinInterfaceCounterReader: InterfaceCounterReader, @unchecked Sendable {
    func readCounters() throws -> [InterfaceCounterReading] {
        var head: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&head) == 0 else {
            throw InterfaceCounterReadError(code: errno)
        }
        defer { freeifaddrs(head) }

        let observedAt = Date()
        let monotonicNanos = DispatchTime.now().uptimeNanoseconds
        var readings: [InterfaceCounterReading] = []
        var cursor = head

        while let current = cursor {
            defer { cursor = current.pointee.ifa_next }
            let item = current.pointee
            guard let address = item.ifa_addr,
                  Int32(address.pointee.sa_family) == AF_LINK,
                  let rawData = item.ifa_data else {
                continue
            }

            let name = String(cString: item.ifa_name)
            let stats = rawData.assumingMemoryBound(to: if_data.self).pointee
            let flags = item.ifa_flags

            readings.append(
                InterfaceCounterReading(
                    interfaceName: name,
                    receivedBytes: UInt64(stats.ifi_ibytes),
                    transmittedBytes: UInt64(stats.ifi_obytes),
                    isUp: (flags & UInt32(IFF_UP)) != 0,
                    isRunning: (flags & UInt32(IFF_RUNNING)) != 0,
                    isLoopback: (flags & UInt32(IFF_LOOPBACK)) != 0,
                    linkType: nil,
                    observedAt: observedAt,
                    monotonicNanos: monotonicNanos
                )
            )
        }

        return readings.sorted { $0.interfaceName < $1.interfaceName }
    }
}
#endif
