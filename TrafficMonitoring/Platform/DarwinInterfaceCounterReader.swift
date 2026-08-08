#if os(macOS)
import Darwin
import Dispatch
import Foundation

struct InterfaceCounterReadError: LocalizedError {
    let operation: String
    let code: Int32

    var errorDescription: String? {
        "\(operation) failed: \(String(cString: strerror(code)))"
    }
}

/// Reads cumulative interface counters from Darwin's routing sysctl using
/// NET_RT_IFLIST2. RTM_IFINFO2 carries `if_data64`, avoiding the 32-bit byte
/// counters exposed by `getifaddrs()` through `struct if_data`.
final class DarwinInterfaceCounterReader: InterfaceCounterReader, @unchecked Sendable {
    func readCounters() throws -> [InterfaceCounterReading] {
        let buffer = try readRouteInterfaceList()
        let observedAt = Date()
        let monotonicNanos = DispatchTime.now().uptimeNanoseconds

        return buffer.withUnsafeBytes { rawBuffer in
            guard let baseAddress = rawBuffer.baseAddress else { return [] }

            var readings: [InterfaceCounterReading] = []
            var offset = 0

            while offset + MemoryLayout<UInt16>.size <= rawBuffer.count {
                let messageLength = Int(
                    baseAddress.loadUnaligned(fromByteOffset: offset, as: UInt16.self)
                )
                guard messageLength > 0, offset + messageLength <= rawBuffer.count else {
                    break
                }

                // Darwin route-message headers share msglen/version/type as
                // their first four bytes. Only RTM_IFINFO2 has if_msghdr2.
                let messageType = baseAddress.loadUnaligned(
                    fromByteOffset: offset + 3,
                    as: UInt8.self
                )

                if Int32(messageType) == RTM_IFINFO2,
                   messageLength >= MemoryLayout<if_msghdr2>.size {
                    let message = baseAddress.loadUnaligned(
                        fromByteOffset: offset,
                        as: if_msghdr2.self
                    )

                    if let name = interfaceName(index: UInt32(message.ifm_index)) {
                        let flags = UInt32(bitPattern: message.ifm_flags)
                        let stats = message.ifm_data

                        readings.append(
                            InterfaceCounterReading(
                                interfaceName: name,
                                receivedBytes: UInt64(stats.ifi_ibytes),
                                transmittedBytes: UInt64(stats.ifi_obytes),
                                isUp: (flags & UInt32(IFF_UP)) != 0,
                                isRunning: (flags & UInt32(IFF_RUNNING)) != 0,
                                isLoopback: (flags & UInt32(IFF_LOOPBACK)) != 0,
                                linkType: UInt8(stats.ifi_type),
                                observedAt: observedAt,
                                monotonicNanos: monotonicNanos
                            )
                        )
                    }
                }

                offset += messageLength
            }

            return readings.sorted { $0.interfaceName < $1.interfaceName }
        }
    }

    private func readRouteInterfaceList() throws -> [UInt8] {
        var mib: [Int32] = [CTL_NET, PF_ROUTE, 0, 0, NET_RT_IFLIST2, 0]

        for _ in 0..<3 {
            var requiredSize: size_t = 0
            let sizeResult = mib.withUnsafeMutableBufferPointer { mibBuffer in
                sysctl(
                    mibBuffer.baseAddress,
                    UInt32(mibBuffer.count),
                    nil,
                    &requiredSize,
                    nil,
                    0
                )
            }
            guard sizeResult == 0 else {
                throw InterfaceCounterReadError(operation: "sysctl size query", code: errno)
            }

            var buffer = [UInt8](repeating: 0, count: requiredSize)
            var actualSize = requiredSize
            let readResult = mib.withUnsafeMutableBufferPointer { mibBuffer in
                buffer.withUnsafeMutableBytes { bytes in
                    sysctl(
                        mibBuffer.baseAddress,
                        UInt32(mibBuffer.count),
                        bytes.baseAddress,
                        &actualSize,
                        nil,
                        0
                    )
                }
            }

            if readResult == 0 {
                if actualSize < buffer.count {
                    buffer.removeSubrange(actualSize..<buffer.count)
                }
                return buffer
            }

            // The routing table can grow between sizing and reading. Retry a
            // bounded number of times instead of returning a partial snapshot.
            if errno != ENOMEM {
                throw InterfaceCounterReadError(operation: "sysctl interface read", code: errno)
            }
        }

        throw InterfaceCounterReadError(operation: "sysctl interface read", code: ENOMEM)
    }

    private func interfaceName(index: UInt32) -> String? {
        var name = [CChar](repeating: 0, count: Int(IFNAMSIZ))
        return name.withUnsafeMutableBufferPointer { buffer in
            guard let baseAddress = buffer.baseAddress,
                  if_indextoname(index, baseAddress) != nil else {
                return nil
            }
            return String(cString: baseAddress)
        }
    }
}
#endif
