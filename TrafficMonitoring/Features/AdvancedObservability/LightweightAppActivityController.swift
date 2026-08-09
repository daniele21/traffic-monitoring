#if os(macOS)
import AppKit
import Foundation

@MainActor
final class LightweightAppActivityController: ObservableObject {
    private static let enabledKey = "lightweightAppActivityPreviewEnabled"

    @Published private(set) var state: LightweightAppActivityState = .disabled
    @Published private(set) var samples: [LightweightProcessNetworkSample] = []
    @Published private(set) var lastUpdatedAt: Date?
    @Published private(set) var errorMessage: String?
    @Published var isEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: Self.enabledKey)
            if !isEnabled { stop() }
        }
    }

    private let sampler = NettopProcessSampler()
    private let applicationAggregator = LightweightApplicationActivityAggregator()
    private let processNameAggregator = LightweightProcessNameActivityAggregator()
    private var samplingTask: Task<Void, Never>?

    init() {
        if UserDefaults.standard.object(forKey: Self.enabledKey) == nil {
            isEnabled = true
        } else {
            isEnabled = UserDefaults.standard.bool(forKey: Self.enabledKey)
        }
        state = isEnabled ? .available : .disabled
    }

    var applications: [LightweightApplicationNetworkSummary] {
        applicationAggregator.aggregate(samples)
    }

    var processNames: [LightweightProcessNameNetworkSummary] {
        processNameAggregator.aggregate(samples)
    }

    var totalDownloadedBytes: UInt64 { saturatingSum(samples.map(\.downloadedBytes)) }
    var totalUploadedBytes: UInt64 { saturatingSum(samples.map(\.uploadedBytes)) }
    var totalBytes: UInt64 { saturatingSum(samples.map(\.totalBytes)) }

    func start() {
        guard isEnabled else {
            state = .disabled
            return
        }
        guard samplingTask == nil else { return }
        guard FileManager.default.isExecutableFile(atPath: NettopProcessSampler.executablePath) else {
            state = .unavailable
            errorMessage = "macOS process network summary tool is unavailable on this system."
            return
        }

        state = .available
        errorMessage = nil
        samplingTask = Task { [weak self] in
            guard let self else { return }
            await self.refresh()
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(15)) } catch { break }
                await self.refresh()
            }
        }
    }

    func stop() {
        samplingTask?.cancel()
        samplingTask = nil
        if isEnabled {
            state = .available
        } else {
            state = .disabled
            samples = []
            lastUpdatedAt = nil
            errorMessage = nil
        }
    }

    func refresh() async {
        guard isEnabled else { return }
        do {
            let rows = try await sampler.sample()
            samples = rows.filter { $0.totalBytes > 0 }
            lastUpdatedAt = Date()
            state = .available
            errorMessage = nil
        } catch {
            state = .failed
            errorMessage = error.localizedDescription
        }
    }

    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        if enabled { start() }
    }

    private func saturatingSum(_ values: [UInt64]) -> UInt64 {
        values.reduce(0) { partial, value in
            let (sum, overflow) = partial.addingReportingOverflow(value)
            return overflow ? .max : sum
        }
    }
}

private struct NettopProcessSampler: Sendable {
    static let executablePath = "/usr/bin/nettop"

    enum SamplingError: LocalizedError {
        case unavailable
        case failed(Int32, String)
        case invalidOutput

        var errorDescription: String? {
            switch self {
            case .unavailable:
                "App Activity Preview is not available on this macOS installation."
            case let .failed(code, message):
                message.isEmpty ? "Process network sampling failed with status \(code)." : message
            case .invalidOutput:
                "macOS returned an unreadable process network summary."
            }
        }
    }

    func sample() async throws -> [LightweightProcessNetworkSample] {
        try await Task.detached(priority: .utility) {
            guard FileManager.default.isExecutableFile(atPath: Self.executablePath) else {
                throw SamplingError.unavailable
            }

            let process = Process()
            process.executableURL = URL(fileURLWithPath: Self.executablePath)
            process.arguments = ["-n", "-P", "-L", "1", "-x", "-J", "bytes_in,bytes_out"]

            let stdout = Pipe()
            let stderr = Pipe()
            process.standardOutput = stdout
            process.standardError = stderr

            try process.run()
            process.waitUntilExit()

            let outputData = stdout.fileHandleForReading.readDataToEndOfFile()
            let errorData = stderr.fileHandleForReading.readDataToEndOfFile()
            let errorText = String(data: errorData, encoding: .utf8) ?? ""

            guard process.terminationStatus == 0 else {
                throw SamplingError.failed(process.terminationStatus, errorText.trimmingCharacters(in: .whitespacesAndNewlines))
            }
            guard let output = String(data: outputData, encoding: .utf8),
                  output.contains("bytes_in") else {
                throw SamplingError.invalidOutput
            }

            let parsed = NettopProcessCSVParser().parse(output, observedAt: Date())
            let parentProcessIDs = ProcessParentTable.snapshot()
            let resolver = MacApplicationIdentityResolver(parentProcessIDs: parentProcessIDs)

            return parsed.map { sample in
                LightweightProcessNetworkSample(
                    processName: sample.processName,
                    processIdentifier: sample.processIdentifier,
                    downloadedBytes: sample.downloadedBytes,
                    uploadedBytes: sample.uploadedBytes,
                    observedAt: sample.observedAt,
                    application: resolver.resolve(
                        processIdentifier: sample.processIdentifier,
                        processName: sample.processName
                    )
                )
            }
        }.value
    }
}

private struct ProcessParentTable: Sendable {
    static func snapshot() -> [Int32: Int32] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = ["-axo", "pid=,ppid="]

        let stdout = Pipe()
        process.standardOutput = stdout
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return [:] }
        } catch {
            return [:]
        }

        let data = stdout.fileHandleForReading.readDataToEndOfFile()
        guard let text = String(data: data, encoding: .utf8) else { return [:] }

        var result: [Int32: Int32] = [:]
        for line in text.split(whereSeparator: \.isNewline) {
            let fields = line.split(whereSeparator: \.isWhitespace)
            guard fields.count >= 2,
                  let pid = Int32(fields[0]),
                  let parentPID = Int32(fields[1]) else {
                continue
            }
            result[pid] = parentPID
        }
        return result
    }
}

private struct MacApplicationIdentityResolver: Sendable {
    let parentProcessIDs: [Int32: Int32]

    func resolve(processIdentifier: Int32?, processName: String) -> LightweightApplicationIdentity? {
        guard var currentPID = processIdentifier, currentPID > 0 else { return nil }

        var visited = Set<Int32>()
        for _ in 0..<16 {
            guard visited.insert(currentPID).inserted else { break }

            if let runningApplication = NSRunningApplication(processIdentifier: pid_t(currentPID)),
               let identity = identity(for: runningApplication) {
                return identity
            }

            guard let parentPID = parentProcessIDs[currentPID], parentPID > 1 else { break }
            currentPID = parentPID
        }

        return nil
    }

    private func identity(for runningApplication: NSRunningApplication) -> LightweightApplicationIdentity? {
        if let sourceURL = runningApplication.bundleURL ?? runningApplication.executableURL,
           let applicationURL = outermostApplicationURL(containing: sourceURL) {
            let bundle = Bundle(url: applicationURL)
            let name = (bundle?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
                ?? (bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String)
                ?? applicationURL.deletingPathExtension().lastPathComponent
            return LightweightApplicationIdentity(
                name: name,
                bundleIdentifier: bundle?.bundleIdentifier ?? runningApplication.bundleIdentifier
            )
        }

        if let name = runningApplication.localizedName, !name.isEmpty {
            return LightweightApplicationIdentity(
                name: name,
                bundleIdentifier: runningApplication.bundleIdentifier
            )
        }

        return nil
    }

    private func outermostApplicationURL(containing url: URL) -> URL? {
        let components = url.standardizedFileURL.pathComponents
        guard components.count > 1 else { return nil }

        var candidate = URL(fileURLWithPath: "/", isDirectory: true)
        for component in components.dropFirst() {
            candidate.appendPathComponent(component, isDirectory: true)
            if component.lowercased().hasSuffix(".app") {
                return candidate
            }
        }
        return nil
    }
}
#endif
