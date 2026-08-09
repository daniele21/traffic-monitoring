#if os(macOS)
import Combine
import Foundation

@MainActor
final class AdvancedObservabilityController: ObservableObject {
    static let enabledDefaultsKey = "advancedObservabilityEnabled"

    @Published private(set) var isEnabled: Bool
    @Published private(set) var snapshot: AdvancedObservabilitySnapshot
    @Published private(set) var bridgeStatus: String = "Core tracking only"
    @Published private(set) var lastError: String?

    private let defaults: UserDefaults
    private let xpcClient: AdvancedObservabilityXPCClient
    private let prototypeBridge: AdvancedObservabilityPrototypeBridge
    private var timer: Timer?

    init(
        defaults: UserDefaults = .standard,
        xpcClient: AdvancedObservabilityXPCClient = AdvancedObservabilityXPCClient(),
        prototypeBridge: AdvancedObservabilityPrototypeBridge = AdvancedObservabilityPrototypeBridge()
    ) {
        self.defaults = defaults
        self.xpcClient = xpcClient
        self.prototypeBridge = prototypeBridge
        isEnabled = defaults.bool(forKey: Self.enabledDefaultsKey)
        snapshot = AdvancedObservabilitySnapshot(providerState: .disabled, byteAccounting: .notValidated, applications: [], lastObservedAt: nil)
        refresh()
    }

    deinit { timer?.invalidate() }

    var providerState: AdvancedObservabilityProviderState { snapshot.providerState }
    var byteAccounting: ByteAccountingCapability { snapshot.byteAccounting }
    var applications: [ApplicationEvidenceSummary] { snapshot.applications }

    var statusExplanation: String {
        switch providerState {
        case .disabled:
            "Advanced app-level observation is off. Normal network analytics continue unchanged."
        case .providerUnavailable:
            "The Advanced Observability system extension is not running or this build cannot activate it. Core network analytics continue normally."
        case .awaitingApproval:
            "macOS approval is required before the Advanced Observability system extension can start."
        case .active:
            byteAccounting == .validated
                ? "Application attribution is active with validated byte accounting."
                : "Application attribution is active. Flow byte accounting is still experimental and is not presented as release-validated evidence."
        case .degraded:
            "Advanced evidence is stale or incomplete, so no definitive app-level conclusion should be drawn."
        }
    }

    func start() {
        guard timer == nil else { return }
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    func stop() { timer?.invalidate(); timer = nil }

    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        defaults.set(enabled, forKey: Self.enabledDefaultsKey)
        refresh()
    }

    func refresh(now: Date = Date()) {
        guard isEnabled else {
            snapshot = AdvancedObservabilitySnapshot(providerState: .disabled, byteAccounting: .notValidated, applications: [], lastObservedAt: nil, generatedAt: now)
            bridgeStatus = "Core tracking only"
            lastError = nil
            return
        }

        bridgeStatus = "Connecting to system extension"
        xpcClient.loadSnapshot { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                switch result {
                case let .success(loaded):
                    if let loaded {
                        self.apply(loaded, now: Date(), bridge: "System extension · XPC")
                    } else {
                        self.applyUnavailable(now: Date(), message: nil)
                    }
                case let .failure(error):
                    // A file snapshot remains available solely for deterministic B2 UI
                    // development; real provider evidence always prefers XPC.
                    if let prototype = try? self.prototypeBridge.loadSnapshot() {
                        self.apply(prototype, now: Date(), bridge: "Developer prototype snapshot")
                    } else {
                        self.applyUnavailable(now: Date(), message: error.localizedDescription)
                    }
                }
            }
        }
    }

    private func apply(_ loaded: AdvancedObservabilitySnapshot, now: Date, bridge: String) {
        let age = now.timeIntervalSince(loaded.generatedAt)
        let state: AdvancedObservabilityProviderState = age <= 20 ? loaded.providerState : .degraded
        snapshot = AdvancedObservabilitySnapshot(
            providerState: state,
            byteAccounting: loaded.byteAccounting,
            applications: loaded.applications,
            lastObservedAt: loaded.lastObservedAt,
            generatedAt: loaded.generatedAt
        )
        bridgeStatus = bridge
        lastError = nil
    }

    private func applyUnavailable(now: Date, message: String?) {
        snapshot = AdvancedObservabilitySnapshot(providerState: .providerUnavailable, byteAccounting: .notValidated, applications: [], lastObservedAt: nil, generatedAt: now)
        bridgeStatus = "Provider unavailable"
        // Connection absence is a supported state in normal/ad-hoc builds, not a red error.
        lastError = nil
        if let message, message.localizedCaseInsensitiveContains("invalid") {
            lastError = message
        }
    }
}

/// Development-only fallback for deterministic B2 UI tests. It is not Network
/// Extension IPC and normal builds never synthesize sample application rows.
struct AdvancedObservabilityPrototypeBridge {
    static let fileName = "advanced-observability-prototype.json"
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) { self.fileManager = fileManager }

    func loadSnapshot() throws -> AdvancedObservabilitySnapshot? {
        let url = snapshotURL
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(AdvancedObservabilitySnapshot.self, from: data)
    }

    private var snapshotURL: URL {
        let base = (try? fileManager.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)) ?? fileManager.temporaryDirectory
        let directory = base.appendingPathComponent("TrafficMonitoring", isDirectory: true).appendingPathComponent("AdvancedObservabilityPrototype", isDirectory: true)
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent(Self.fileName)
    }
}
#endif
