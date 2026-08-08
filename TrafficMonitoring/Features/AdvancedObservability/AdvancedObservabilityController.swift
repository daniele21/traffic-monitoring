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
    private let bridge: AdvancedObservabilityBridgeStore
    private var timer: Timer?

    init(defaults: UserDefaults = .standard, bridge: AdvancedObservabilityBridgeStore = AdvancedObservabilityBridgeStore()) {
        self.defaults = defaults
        self.bridge = bridge
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
            "The signed Network Extension provider is not available to this build. Core network tracking continues normally."
        case .awaitingApproval:
            "macOS approval is still required before app-level flow evidence can be observed."
        case .active:
            byteAccounting == .validated
                ? "Application attribution is active with validated byte accounting."
                : "Application attribution is active. Byte accounting is still experimental and is not presented as authoritative."
        case .degraded:
            "Advanced observation is enabled, but the provider evidence is stale or incomplete."
        }
    }

    func start() {
        guard timer == nil else { return }
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

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

        do {
            guard let loaded = try bridge.loadSnapshot() else {
                snapshot = AdvancedObservabilitySnapshot(
                    providerState: bridge.sharedContainerAvailable ? .awaitingApproval : .providerUnavailable,
                    byteAccounting: .notValidated,
                    applications: [],
                    lastObservedAt: nil,
                    generatedAt: now
                )
                bridgeStatus = bridge.sharedContainerAvailable ? "Waiting for provider evidence" : "Provider unavailable in this build"
                lastError = nil
                return
            }

            let age = now.timeIntervalSince(loaded.generatedAt)
            let state: AdvancedObservabilityProviderState = age <= 20 ? loaded.providerState : .degraded
            snapshot = AdvancedObservabilitySnapshot(
                providerState: state,
                byteAccounting: loaded.byteAccounting,
                applications: loaded.applications,
                lastObservedAt: loaded.lastObservedAt,
                generatedAt: loaded.generatedAt
            )
            bridgeStatus = bridge.sharedContainerAvailable ? "Shared provider bridge" : "Developer bridge"
            lastError = nil
        } catch {
            snapshot = AdvancedObservabilitySnapshot(providerState: .degraded, byteAccounting: .notValidated, applications: [], lastObservedAt: nil, generatedAt: now)
            bridgeStatus = "Bridge read failed"
            lastError = error.localizedDescription
        }
    }
}

struct AdvancedObservabilityBridgeStore {
    static let appGroupIdentifier = "group.com.daniele21.trafficmonitoring"
    static let fileName = "advanced-observability-snapshot.json"

    private let fileManager: FileManager

    init(fileManager: FileManager = .default) { self.fileManager = fileManager }

    var sharedContainerAvailable: Bool {
        fileManager.containerURL(forSecurityApplicationGroupIdentifier: Self.appGroupIdentifier) != nil
    }

    func loadSnapshot() throws -> AdvancedObservabilitySnapshot? {
        let url = snapshotURL
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(AdvancedObservabilitySnapshot.self, from: data)
    }

    private var snapshotURL: URL {
        if let shared = fileManager.containerURL(forSecurityApplicationGroupIdentifier: Self.appGroupIdentifier) {
            return shared.appendingPathComponent(Self.fileName)
        }
        let base = (try? fileManager.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)) ?? fileManager.temporaryDirectory
        let directory = base.appendingPathComponent("TrafficMonitoring", isDirectory: true).appendingPathComponent("AdvancedObservability", isDirectory: true)
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent(Self.fileName)
    }
}
#endif
