#if os(macOS)
import Combine
import Foundation
import OSLog

@MainActor
final class DiagnosticsViewModel: ObservableObject {
    @Published private(set) var rows: [DiagnosticInterfaceRow] = []
    @Published private(set) var sessionUsage: [SessionNetworkUsage] = []
    @Published private(set) var lastUpdated: Date?
    @Published private(set) var errorMessage: String?
    @Published private(set) var isRunning = false

    private let counterReader: InterfaceCounterReader
    private let contextProvider: NetworkContextProviding
    private let classifier = InterfaceClassifier()
    private let calculator: DeltaCalculator
    private let configuration: TrackingConfiguration
    private let usageStore: LocalUsageStore
    private var loopTask: Task<Void, Never>?
    private var previousByInterface: [String: InterfaceCounterReading] = [:]
    private var previousIdentityByInterface: [String: String] = [:]
    private var sessionAccumulator = SessionUsageAccumulator()

    init(
        usageStore: LocalUsageStore,
        counterReader: InterfaceCounterReader = DarwinInterfaceCounterReader(),
        contextProvider: NetworkContextProviding = AppleNetworkContextProvider(),
        configuration: TrackingConfiguration = .default
    ) {
        self.usageStore = usageStore
        self.counterReader = counterReader
        self.contextProvider = contextProvider
        self.configuration = configuration
        calculator = DeltaCalculator(configuration: configuration.deltaValidation)
    }

    deinit {
        loopTask?.cancel()
    }

    func start() {
        guard loopTask == nil else { return }
        isRunning = true
        loopTask = Task { [weak self] in
            guard let self else { return }
            await sample()
            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: configuration.sampleInterval)
                } catch {
                    break
                }
                await sample()
            }
        }
    }

    func stop() {
        loopTask?.cancel()
        loopTask = nil
        isRunning = false

        do {
            try usageStore.flush()
        } catch {
            Logger.persistence.error("Final usage checkpoint failed: \(error.localizedDescription, privacy: .public)")
        }

        previousByInterface.removeAll()
        previousIdentityByInterface.removeAll()
    }

    func sample() async {
        do {
            let readings = try counterReader.readCounters()
            let context = await contextProvider.currentSnapshot()
            var nextRows: [DiagnosticInterfaceRow] = []
            var encounteredContextBoundary = false
            var metadataDegraded = false
            var unknownNetwork = false

            for reading in readings {
                let classification = classifier.classify(
                    reading,
                    wifiInterfaceNames: context.wifiInterfaceNames
                )
                let identity = identityKey(for: reading.interfaceName, classification: classification, context: context)
                let displayName = networkName(for: reading.interfaceName, classification: classification, context: context)
                let contextChanged = previousIdentityByInterface[reading.interfaceName].map { $0 != identity } ?? false

                var delta = TrafficDelta(
                    interfaceName: reading.interfaceName,
                    receivedBytes: 0,
                    transmittedBytes: 0,
                    elapsedSeconds: 0
                )

                let included = isIncluded(classification)

                // An active Wi-Fi interface without SSID is an identity-quality issue even while idle.
                if included,
                   case .wifi = classification,
                   context.wifiSSIDByInterface[reading.interfaceName] == nil {
                    metadataDegraded = true
                    unknownNetwork = true
                }

                if included, !contextChanged, let previous = previousByInterface[reading.interfaceName] {
                    switch calculator.calculate(previous: previous, current: reading) {
                    case let .accepted(value):
                        delta = value
                        let kind = connectionKind(for: classification)

                        // Wired/other fallback identities only degrade evidence when they actually
                        // contribute traffic. Merely-present zero-byte interfaces should not lower
                        // the evidence quality for the whole selected period.
                        if value.totalBytes > 0 {
                            switch classification {
                            case .wired, .otherPhysical:
                                metadataDegraded = true
                            case .wifi, .excluded:
                                break
                            }
                        }

                        sessionAccumulator.record(
                            identityKey: identity,
                            networkName: displayName,
                            connectionKind: kind,
                            isExpensive: context.isExpensive,
                            observedAt: reading.observedAt,
                            delta: value
                        )

                        usageStore.record(
                            identityKey: identity,
                            networkName: displayName,
                            connectionKind: kind,
                            interfaceName: reading.interfaceName,
                            isExpensive: context.isExpensive,
                            isConstrained: context.isConstrained,
                            observedAt: reading.observedAt,
                            delta: value
                        )

                    case let .discarded(reason):
                        Logger.diagnostics.debug(
                            "Discarded interval for \(reading.interfaceName, privacy: .public): \(String(describing: reason), privacy: .public)"
                        )
                    }
                } else if contextChanged {
                    encounteredContextBoundary = true
                    Logger.context.debug("Context boundary on \(reading.interfaceName, privacy: .public); resetting baseline")
                }

                previousByInterface[reading.interfaceName] = reading
                previousIdentityByInterface[reading.interfaceName] = identity

                nextRows.append(
                    DiagnosticInterfaceRow(
                        id: reading.interfaceName,
                        interfaceName: reading.interfaceName,
                        classification: classificationLabel(classification),
                        rawReceivedBytes: reading.receivedBytes,
                        rawTransmittedBytes: reading.transmittedBytes,
                        deltaReceivedBytes: delta.receivedBytes,
                        deltaTransmittedBytes: delta.transmittedBytes,
                        downloadBytesPerSecond: delta.downloadBytesPerSecond,
                        uploadBytesPerSecond: delta.uploadBytesPerSecond,
                        networkName: displayName,
                        isExpensive: context.isExpensive,
                        isConstrained: context.isConstrained,
                        isIncluded: included
                    )
                )
            }

            let observedAt = readings.map(\.observedAt).max() ?? Date()
            usageStore.recordCoverage(
                observedAt: observedAt,
                metadataDegraded: metadataDegraded,
                unknownNetwork: unknownNetwork,
                trackingDegraded: usageStore.persistenceErrorMessage != nil
            )

            do {
                if encounteredContextBoundary {
                    try usageStore.flush()
                } else {
                    try usageStore.flushIfNeeded()
                }
            } catch {
                Logger.persistence.error("Usage checkpoint failed: \(error.localizedDescription, privacy: .public)")
            }

            rows = nextRows
            sessionUsage = sessionAccumulator.networks
            lastUpdated = Date()
            errorMessage = nil
        } catch {
            let observedAt = Date()
            usageStore.recordCoverage(
                observedAt: observedAt,
                metadataDegraded: false,
                unknownNetwork: false,
                trackingDegraded: true
            )
            try? usageStore.flushIfNeeded(now: observedAt)
            errorMessage = error.localizedDescription
            Logger.counters.error("Counter read failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    var includedRows: [DiagnosticInterfaceRow] {
        rows.filter(\.isIncluded)
    }

    var totalDownloadBytesPerSecond: Double {
        includedRows.reduce(0) { $0 + $1.downloadBytesPerSecond }
    }

    var totalUploadBytesPerSecond: Double {
        includedRows.reduce(0) { $0 + $1.uploadBytesPerSecond }
    }

    var currentNetworkName: String {
        includedRows.first?.networkName ?? "Offline"
    }

    var sessionDownloadedBytes: UInt64 {
        sessionAccumulator.downloadedBytes
    }

    var sessionUploadedBytes: UInt64 {
        sessionAccumulator.uploadedBytes
    }

    var sessionTotalBytes: UInt64 {
        sessionAccumulator.totalBytes
    }

    var hasUnnamedWiFiUsage: Bool {
        sessionUsage.contains { $0.connectionKind == .wifi && $0.networkName == "Wi-Fi · SSID unavailable" }
    }

    private func isIncluded(_ classification: InterfaceClassification) -> Bool {
        if case .excluded = classification { return false }
        return true
    }

    private func classificationLabel(_ classification: InterfaceClassification) -> String {
        switch classification {
        case .wifi: "Wi-Fi"
        case .wired: "Wired"
        case .otherPhysical: "Other physical"
        case let .excluded(reason): "Excluded · \(reason)"
        }
    }

    private func connectionKind(for classification: InterfaceClassification) -> NetworkConnectionKind {
        switch classification {
        case .wifi: .wifi
        case .wired: .wired
        case .otherPhysical, .excluded: .other
        }
    }

    private func identityKey(
        for interfaceName: String,
        classification: InterfaceClassification,
        context: NetworkContextSnapshot
    ) -> String {
        switch classification {
        case .wifi:
            return "wifi:\(interfaceName):\(context.wifiSSIDByInterface[interfaceName] ?? "ssid-unavailable")"
        case .wired:
            return "wired:\(interfaceName):unknown-network"
        case .otherPhysical:
            return "other:\(interfaceName)"
        case .excluded:
            return "excluded:\(interfaceName)"
        }
    }

    private func networkName(
        for interfaceName: String,
        classification: InterfaceClassification,
        context: NetworkContextSnapshot
    ) -> String {
        switch classification {
        case .wifi:
            return context.wifiSSIDByInterface[interfaceName] ?? "Wi-Fi · SSID unavailable"
        case .wired:
            return "Ethernet · \(interfaceName)"
        case .otherPhysical:
            return "Physical · \(interfaceName)"
        case .excluded:
            return "—"
        }
    }
}
#endif
