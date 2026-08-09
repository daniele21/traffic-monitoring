import Foundation

public struct IPLocalityClassifier: Sendable {
    public init() {}

    public func classify(host: String?) -> FlowLocality {
        guard let raw = host?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return .unknown
        }

        let host = stripIPv6Brackets(raw.lowercased())

        if host == "localhost" || host == "::1" || isIPv4(host, in: (127, 0...255)) {
            return .loopback
        }

        guard isIPAddress(host) else {
            // Do not resolve hostnames here. Classification must remain deterministic
            // and must not create extra DNS/network activity.
            return .unknown
        }

        if isPrivateIPv4(host) || isLocalIPv6(host) {
            return .localNetwork
        }

        return .external
    }

    private func isPrivateIPv4(_ host: String) -> Bool {
        guard let octets = ipv4Octets(host) else { return false }
        if octets[0] == 10 { return true }
        if octets[0] == 172 && (16...31).contains(octets[1]) { return true }
        if octets[0] == 192 && octets[1] == 168 { return true }
        if octets[0] == 169 && octets[1] == 254 { return true }
        return false
    }

    private func isLocalIPv6(_ host: String) -> Bool {
        guard host.contains(":") else { return false }
        if host.hasPrefix("fe8") || host.hasPrefix("fe9") || host.hasPrefix("fea") || host.hasPrefix("feb") {
            return true // fe80::/10 link-local
        }
        if host.hasPrefix("fc") || host.hasPrefix("fd") {
            return true // fc00::/7 unique-local
        }
        return false
    }

    private func isIPAddress(_ host: String) -> Bool {
        if ipv4Octets(host) != nil { return true }
        return host.contains(":") && host.allSatisfy { $0.isHexDigit || $0 == ":" || $0 == "." || $0 == "%" || $0.isLetter || $0.isNumber }
    }

    private func ipv4Octets(_ host: String) -> [Int]? {
        let parts = host.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 4 else { return nil }
        let values = parts.compactMap { Int($0) }
        guard values.count == 4, values.allSatisfy({ (0...255).contains($0) }) else { return nil }
        return values
    }

    private func isIPv4(_ host: String, in firstOctetAndSecondRange: (Int, ClosedRange<Int>)) -> Bool {
        guard let octets = ipv4Octets(host) else { return false }
        return octets[0] == firstOctetAndSecondRange.0 && firstOctetAndSecondRange.1.contains(octets[1])
    }

    private func stripIPv6Brackets(_ host: String) -> String {
        guard host.first == "[", let closing = host.firstIndex(of: "]") else { return host }
        return String(host[host.index(after: host.startIndex)..<closing])
    }
}
