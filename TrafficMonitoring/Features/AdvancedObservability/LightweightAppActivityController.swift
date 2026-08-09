#if os(macOS)
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
    private var samplingTask: Task<Void, Never>?

    init() {
        if UserDefaults.standard.object(forKey: Self.enabledKey) == nil {
            isEnabled = true
        } else {
            isEnabled = UserDefaults.standard.bool(forKey: Self.enabledKey)
        }
        state = isEnabled ? .available : .disabled
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
            samples = rows.filter { $0.totalBytes > 0 }.prefix(100).map { $0 }
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

            return NettopProcessCSVParser().parse(output, observedAt: Date())
        }.value
    }
}
#endif
