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
    private let prototypeBridge: AdvancedObservabilityPrototypeBridge
    private var timer: Timer?

    init(defaults: UserDefaults = .standard, prototypeBridge: AdvancedObservabilityPrototypeBridge = AdvancedObservabilityPrototypeBridge()) {
        self.defaults = defaults
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
            "The current macOS content-filter spike can observe app flow metadata inside its provider, but B0 found no supported provider-to-app evidence channel for this product architecture. Core tracking remains available."
        case .awaitingApproval:
            "A future supported advanced provider would still require macOS approval before observation can start."
        case .active:
            byteAccounting == .validated
                ? "Prototype application evidence is active with validated byte accounting."
                : "Prototype application evidence is active. Byte accounting is not release-validated."
        case .degraded:
            "Prototype evidence is stale or incomplete, so no definitive app-level conclusion should be drawn."
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

        do {
            guard let loaded = try prototypeBridge.loadSnapshot() else {
                snapshot = AdvancedObservabilitySnapshot(providerState: .providerUnavailable, byteAccounting: .notValidated, applications: [], lastObservedAt: nil, generatedAt: now)
                bridgeStatus = "B0 platform bridge blocked"
                lastError = nil
                return
            }

            let age = now.timeIntervalSince(loaded.generatedAt)
            let state: AdvancedObservabilityProviderState = age <= 20 ? loaded.providerState : .degraded
            snapshot = AdvancedObservabilitySnapshot(providerState: state, byteAccounting: loaded.byteAccounting, applications: loaded.applications, lastObservedAt: loaded.lastObservedAt, generatedAt: loaded.generatedAt)
            bridgeStatus = "Developer prototype snapshot"
            lastError = nil
        } catch {
            snapshot = AdvancedObservabilitySnapshot(providerState: .degraded, byteAccounting: .notValidated, applications: [], lastObservedAt: nil, generatedAt: now)
            bridgeStatus = "Prototype snapshot read failed"
            lastError = error.localizedDescription
        }
    }
}

/// Development-only handoff for deterministic B1/B2 UI tests.
/// It is deliberately not presented as a production Network Extension IPC path:
/// Apple's filter data provider sandbox blocks disk writes and IPC on macOS.
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
