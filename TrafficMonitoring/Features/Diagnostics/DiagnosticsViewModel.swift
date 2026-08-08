#if os(macOS)
import Combine
import Foundation
import OSLog

@MainActor
final class DiagnosticsViewModel: ObservableObject {
    @Published private(set) var rows: [DiagnosticInterfaceRow] = []
    @Published private(set) var lastUpdated: Date?
    @Published private(set) var errorMessage: String?
    @Published private(set) var isRunning = false

    private let counterReader: InterfaceCounterReader
    private let contextProvider: NetworkContextProviding
    private let classifier = InterfaceClassifier()
    private let calculator: DeltaCalculator
    private let configuration: TrackingConfiguration
    private var loopTask: Task<Void, Never>?
    private var previousByInterface: [String: InterfaceCounterReading] = [:]
    private var previousIdentityByInterface: [String: String] = [:]

    init(
        counterReader: InterfaceCounterReader = DarwinInterfaceCounterReader(),
        contextProvider: NetworkContextProviding = AppleNetworkContextProvider(),
        configuration: TrackingConfiguration = .default
    ) {
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
        previousByInterface.removeAll()
        previousIdentityByInterface.removeAll()
    }

    func sample() async {
        do {
            let readings = try counterReader.readCounters()
            let context = await contextProvider.currentSnapshot()
            var nextRows: [DiagnosticInterfaceRow] = []

            for reading in readings {
                let classification = classifier.classify(
                    reading,
                    wifiInterfaceNames: context.wifiInterfaceNames
                )
                let identity = identityKey(for: reading.interfaceName, classification: classification, context: context)
                let contextChanged = previousIdentityByInterface[reading.interfaceName].map { $0 != identity } ?? false

                var delta = TrafficDelta(
                    interfaceName: reading.interfaceName,
                    receivedBytes: 0,
                    transmittedBytes: 0,
                    elapsedSeconds: 0
                )

                let included = isIncluded(classification)
                if included, !contextChanged, let previous = previousByInterface[reading.interfaceName] {
                    switch calculator.calculate(previous: previous, current: reading) {
                    case let .accepted(value):
                        delta = value
                    case let .discarded(reason):
                        Logger.diagnostics.debug(
                            "Discarded interval for \(reading.interfaceName, privacy: .public): \(String(describing: reason), privacy: .public)"
                        )
                    }
                } else if contextChanged {
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
                        networkName: networkName(for: reading.interfaceName, classification: classification, context: context),
                        isExpensive: context.isExpensive,
                        isConstrained: context.isConstrained,
                        isIncluded: included
                    )
                )
            }

            rows = nextRows
            lastUpdated = Date()
            errorMessage = nil
        } catch {
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
