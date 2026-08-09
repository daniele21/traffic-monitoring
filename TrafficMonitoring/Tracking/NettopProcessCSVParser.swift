import Foundation

public struct NettopProcessCSVParser: Sendable {
    public init() {}

    public func parse(_ text: String, observedAt: Date = Date()) -> [LightweightProcessNetworkSample] {
        let rows = text.split(whereSeparator: \.isNewline).map(String.init)
        guard !rows.isEmpty else { return [] }

        var results: [LightweightProcessNetworkSample] = []
        for line in rows.dropFirst() {
            let columns = csvColumns(line)
            guard columns.count >= 3 else { continue }

            let processField = columns[0].trimmingCharacters(in: .whitespacesAndNewlines)
            guard !processField.isEmpty,
                  let downloaded = UInt64(columns[1].trimmingCharacters(in: .whitespacesAndNewlines)),
                  let uploaded = UInt64(columns[2].trimmingCharacters(in: .whitespacesAndNewlines)) else {
                continue
            }

            let identity = splitProcessField(processField)
            results.append(
                LightweightProcessNetworkSample(
                    processName: identity.name,
                    processIdentifier: identity.pid,
                    downloadedBytes: downloaded,
                    uploadedBytes: uploaded,
                    observedAt: observedAt
                )
            )
        }

        return results.sorted {
            if $0.totalBytes == $1.totalBytes {
                return $0.processName.localizedCaseInsensitiveCompare($1.processName) == .orderedAscending
            }
            return $0.totalBytes > $1.totalBytes
        }
    }

    private func splitProcessField(_ field: String) -> (name: String, pid: Int32?) {
        guard let separator = field.lastIndex(of: ".") else { return (field, nil) }
        let suffix = String(field[field.index(after: separator)...])
        guard !suffix.isEmpty,
              suffix.allSatisfy(\.isNumber),
              let pid = Int32(suffix) else {
            return (field, nil)
        }

        let name = String(field[..<separator])
        return (name.isEmpty ? field : name, pid)
    }

    private func csvColumns(_ line: String) -> [String] {
        var result: [String] = []
        var current = ""
        var quoted = false
        var index = line.startIndex

        while index < line.endIndex {
            let character = line[index]
            if character == "\"" {
                let next = line.index(after: index)
                if quoted, next < line.endIndex, line[next] == "\"" {
                    current.append("\"")
                    index = line.index(after: next)
                    continue
                }
                quoted.toggle()
            } else if character == ",", !quoted {
                result.append(current)
                current = ""
            } else {
                current.append(character)
            }
            index = line.index(after: index)
        }
        result.append(current)
        return result
    }
}
