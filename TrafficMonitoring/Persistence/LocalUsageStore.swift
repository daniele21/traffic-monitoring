#if os(macOS)
import Foundation
import SwiftData

@MainActor
final class LocalUsageStore {
    enum StoreError: LocalizedError {
        case byteCounterOverflow

        var errorDescription: String? {
            switch self {
            case .byteCounterOverflow:
                "A stored byte counter exceeded the supported persistence range."
            }
        }
    }

    private struct PendingBucket {
        let bucketKey: String
        let identityKey: String
        var networkName: String
        var connectionKind: NetworkConnectionKind
        let interfaceName: String
        let startedAt: Date
        let endedAt: Date
        var downloadedBytes: UInt64
        var uploadedBytes: UInt64
        var isExpensive: Bool
        var isConstrained: Bool
        var lastObservedAt: Date
    }

    private struct PendingCoverage {
        let bucketKey: String
        let startedAt: Date
        let endedAt: Date
        var activeSeconds: TimeInterval
        var healthySeconds: TimeInterval
        var metadataDegradedSeconds: TimeInterval
        var trackingDegradedSeconds: TimeInterval
        var unknownNetworkSeconds: TimeInterval
        var lastObservedAt: Date
    }

    let persistsAcrossRelaunches: Bool
    private(set) var persistenceErrorMessage: String?
    private(set) var lastCheckpointAt: Date?

    private let container: ModelContainer
    private let context: ModelContext
    private let checkpointInterval: TimeInterval
    private let bucketInterval: TimeInterval
    private let maximumContinuousObservationGap: TimeInterval
    private var pendingByKey: [String: PendingBucket] = [:]
    private var pendingCoverageByKey: [String: PendingCoverage] = [:]
    private var lastCoverageObservedAt: Date?
    private var lastFlushAttemptAt: Date

    init(
        inMemory: Bool = false,
        checkpointInterval: TimeInterval = 15,
        bucketInterval: TimeInterval = 300,
        maximumContinuousObservationGap: TimeInterval = 10
    ) throws {
        container = try PersistenceBootstrap.makeContainer(inMemory: inMemory)
        context = ModelContext(container)
        context.autosaveEnabled = false
        persistsAcrossRelaunches = !inMemory
        self.checkpointInterval = checkpointInterval
        self.bucketInterval = bucketInterval
        self.maximumContinuousObservationGap = maximumContinuousObservationGap
        lastFlushAttemptAt = Date()
    }

    static func makeDefault() -> LocalUsageStore {
        do {
            return try LocalUsageStore()
        } catch {
            let fallback = try! LocalUsageStore(inMemory: true)
            fallback.persistenceErrorMessage = "History could not be opened on disk. Usage will be kept only until the app closes: \(error.localizedDescription)"
            return fallback
        }
    }

    func record(
        identityKey: String,
        networkName: String,
        connectionKind: NetworkConnectionKind,
        interfaceName: String,
        isExpensive: Bool,
        isConstrained: Bool,
        observedAt: Date,
        delta: TrafficDelta
    ) {
        guard delta.totalBytes > 0 else { return }

        let startedAt = bucketStart(containing: observedAt)
        let endedAt = startedAt.addingTimeInterval(bucketInterval)
        let key = makeBucketKey(identityKey: identityKey, interfaceName: interfaceName, startedAt: startedAt)

        if var pending = pendingByKey[key] {
            pending.networkName = networkName
            pending.connectionKind = connectionKind
            pending.downloadedBytes = saturatedAdd(pending.downloadedBytes, delta.receivedBytes)
            pending.uploadedBytes = saturatedAdd(pending.uploadedBytes, delta.transmittedBytes)
            pending.isExpensive = pending.isExpensive || isExpensive
            pending.isConstrained = pending.isConstrained || isConstrained
            pending.lastObservedAt = max(pending.lastObservedAt, observedAt)
            pendingByKey[key] = pending
        } else {
            pendingByKey[key] = PendingBucket(
                bucketKey: key,
                identityKey: identityKey,
                networkName: networkName,
                connectionKind: connectionKind,
                interfaceName: interfaceName,
                startedAt: startedAt,
                endedAt: endedAt,
                downloadedBytes: delta.receivedBytes,
                uploadedBytes: delta.transmittedBytes,
                isExpensive: isExpensive,
                isConstrained: isConstrained,
                lastObservedAt: observedAt
            )
        }
    }

    /// Records observation coverage without writing one row per sample.
    /// Long gaps are deliberately not counted as observed time so sleep, crashes,
    /// or periods when the app was not running remain visible as coverage gaps.
    func recordCoverage(
        observedAt: Date,
        metadataDegraded: Bool,
        unknownNetwork: Bool,
        trackingDegraded: Bool
    ) {
        defer { lastCoverageObservedAt = observedAt }
        guard let previous = lastCoverageObservedAt else { return }

        let elapsed = observedAt.timeIntervalSince(previous)
        guard elapsed > 0 else { return }

        let countedDuration = min(elapsed, maximumContinuousObservationGap)
        let countedStart = observedAt.addingTimeInterval(-countedDuration)
        recordCoverageSlice(
            from: countedStart,
            to: observedAt,
            metadataDegraded: metadataDegraded,
            unknownNetwork: unknownNetwork,
            trackingDegraded: trackingDegraded
        )
    }

    func flushIfNeeded(now: Date = Date()) throws {
        guard now.timeIntervalSince(lastFlushAttemptAt) >= checkpointInterval else { return }
        try flush(now: now)
    }

    func flush(now: Date = Date()) throws {
        lastFlushAttemptAt = now
        guard !pendingByKey.isEmpty || !pendingCoverageByKey.isEmpty else {
            lastCheckpointAt = now
            return
        }

        do {
            for pending in pendingByKey.values {
                try upsertProfile(for: pending)
                try upsertBucket(pending)
            }
            for coverage in pendingCoverageByKey.values {
                try upsertCoverage(coverage)
            }
            try context.save()
            pendingByKey.removeAll(keepingCapacity: true)
            pendingCoverageByKey.removeAll(keepingCapacity: true)
            lastCheckpointAt = now
            if persistsAcrossRelaunches {
                persistenceErrorMessage = nil
            }
        } catch {
            context.rollback()
            persistenceErrorMessage = "Usage history could not be saved: \(error.localizedDescription)"
            throw error
        }
    }

    func snapshots(in period: DateInterval?) throws -> [UsageBucketSnapshot] {
        let entities: [UsageBucketEntity]

        if let period {
            let start = period.start
            let end = period.end
            let descriptor = FetchDescriptor<UsageBucketEntity>(
                predicate: #Predicate<UsageBucketEntity> { bucket in
                    bucket.startedAt < end && bucket.endedAt > start
                },
                sortBy: [SortDescriptor(\UsageBucketEntity.startedAt)]
            )
            entities = try context.fetch(descriptor)
        } else {
            let descriptor = FetchDescriptor<UsageBucketEntity>(
                sortBy: [SortDescriptor(\UsageBucketEntity.startedAt)]
            )
            entities = try context.fetch(descriptor)
        }

        let presentationNames = try profilePresentationNames()
        var result = entities.compactMap { entity in
            snapshot(from: entity, presentationNames: presentationNames)
        }

        for pending in pendingByKey.values where overlaps(pending, period: period) {
            result.append(
                UsageBucketSnapshot(
                    bucketKey: "pending:\(pending.bucketKey)",
                    identityKey: pending.identityKey,
                    networkName: presentationNames[pending.identityKey] ?? pending.networkName,
                    connectionKind: pending.connectionKind,
                    interfaceName: pending.interfaceName,
                    startedAt: pending.startedAt,
                    endedAt: pending.endedAt,
                    downloadedBytes: pending.downloadedBytes,
                    uploadedBytes: pending.uploadedBytes,
                    isExpensive: pending.isExpensive,
                    isConstrained: pending.isConstrained,
                    lastObservedAt: pending.lastObservedAt
                )
            )
        }

        return result.sorted { $0.startedAt < $1.startedAt }
    }

    func coverageSnapshots(in period: DateInterval?) throws -> [EvidenceCoverageSnapshot] {
        let entities: [EvidenceCoverageEntity]

        if let period {
            let start = period.start
            let end = period.end
            let descriptor = FetchDescriptor<EvidenceCoverageEntity>(
                predicate: #Predicate<EvidenceCoverageEntity> { bucket in
                    bucket.startedAt < end && bucket.endedAt > start
                },
                sortBy: [SortDescriptor(\EvidenceCoverageEntity.startedAt)]
            )
            entities = try context.fetch(descriptor)
        } else {
            entities = try context.fetch(
                FetchDescriptor<EvidenceCoverageEntity>(sortBy: [SortDescriptor(\EvidenceCoverageEntity.startedAt)])
            )
        }

        var result = entities.map(coverageSnapshot(from:))
        for pending in pendingCoverageByKey.values where overlaps(pending, period: period) {
            result.append(
                EvidenceCoverageSnapshot(
                    bucketKey: "pending:\(pending.bucketKey)",
                    startedAt: pending.startedAt,
                    endedAt: pending.endedAt,
                    activeSeconds: pending.activeSeconds,
                    healthySeconds: pending.healthySeconds,
                    metadataDegradedSeconds: pending.metadataDegradedSeconds,
                    trackingDegradedSeconds: pending.trackingDegradedSeconds,
                    unknownNetworkSeconds: pending.unknownNetworkSeconds,
                    lastObservedAt: pending.lastObservedAt
                )
            )
        }
        return result.sorted { $0.startedAt < $1.startedAt }
    }

    func renameNetwork(identityKey: String, alias: String?) throws {
        try flush()
        let identity = identityKey
        var descriptor = FetchDescriptor<NetworkProfileEntity>(
            predicate: #Predicate<NetworkProfileEntity> { profile in
                profile.identityKey == identity
            }
        )
        descriptor.fetchLimit = 1
        guard let profile = try context.fetch(descriptor).first else { return }

        let trimmed = alias?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        profile.displayAlias = trimmed.isEmpty ? nil : trimmed
        try context.save()
    }

    func alias(for identityKey: String) throws -> String? {
        let identity = identityKey
        var descriptor = FetchDescriptor<NetworkProfileEntity>(
            predicate: #Predicate<NetworkProfileEntity> { profile in
                profile.identityKey == identity
            }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first?.displayAlias
    }

    private func recordCoverageSlice(
        from start: Date,
        to end: Date,
        metadataDegraded: Bool,
        unknownNetwork: Bool,
        trackingDegraded: Bool
    ) {
        var cursor = start
        while cursor < end {
            let bucketStartDate = bucketStart(containing: cursor)
            let bucketEndDate = bucketStartDate.addingTimeInterval(bucketInterval)
            let sliceEnd = min(end, bucketEndDate)
            let duration = max(0, sliceEnd.timeIntervalSince(cursor))
            guard duration > 0 else { break }

            let key = "coverage:\(Int64(bucketStartDate.timeIntervalSince1970))"
            var pending = pendingCoverageByKey[key] ?? PendingCoverage(
                bucketKey: key,
                startedAt: bucketStartDate,
                endedAt: bucketEndDate,
                activeSeconds: 0,
                healthySeconds: 0,
                metadataDegradedSeconds: 0,
                trackingDegradedSeconds: 0,
                unknownNetworkSeconds: 0,
                lastObservedAt: sliceEnd
            )

            pending.activeSeconds += duration
            if !trackingDegraded { pending.healthySeconds += duration }
            if metadataDegraded { pending.metadataDegradedSeconds += duration }
            if trackingDegraded { pending.trackingDegradedSeconds += duration }
            if unknownNetwork { pending.unknownNetworkSeconds += duration }
            pending.lastObservedAt = max(pending.lastObservedAt, sliceEnd)
            pendingCoverageByKey[key] = pending
            cursor = sliceEnd
        }
    }

    private func upsertProfile(for pending: PendingBucket) throws {
        let identity = pending.identityKey
        var descriptor = FetchDescriptor<NetworkProfileEntity>(
            predicate: #Predicate<NetworkProfileEntity> { profile in
                profile.identityKey == identity
            }
        )
        descriptor.fetchLimit = 1

        if let existing = try context.fetch(descriptor).first {
            existing.networkName = pending.networkName
            existing.connectionKindRaw = pending.connectionKind.rawValue
            existing.interfaceName = pending.interfaceName
            existing.firstSeenAt = min(existing.firstSeenAt, pending.startedAt)
            existing.lastSeenAt = max(existing.lastSeenAt, pending.lastObservedAt)
            existing.lastKnownExpensive = pending.isExpensive
            existing.lastKnownConstrained = pending.isConstrained
        } else {
            context.insert(
                NetworkProfileEntity(
                    identityKey: pending.identityKey,
                    networkName: pending.networkName,
                    connectionKindRaw: pending.connectionKind.rawValue,
                    interfaceName: pending.interfaceName,
                    firstSeenAt: pending.startedAt,
                    lastSeenAt: pending.lastObservedAt,
                    lastKnownExpensive: pending.isExpensive,
                    lastKnownConstrained: pending.isConstrained
                )
            )
        }
    }

    private func upsertBucket(_ pending: PendingBucket) throws {
        let key = pending.bucketKey
        var descriptor = FetchDescriptor<UsageBucketEntity>(
            predicate: #Predicate<UsageBucketEntity> { bucket in
                bucket.bucketKey == key
            }
        )
        descriptor.fetchLimit = 1

        if let existing = try context.fetch(descriptor).first {
            existing.networkName = pending.networkName
            existing.connectionKindRaw = pending.connectionKind.rawValue
            existing.downloadedBytes = try adding(pending.downloadedBytes, to: existing.downloadedBytes)
            existing.uploadedBytes = try adding(pending.uploadedBytes, to: existing.uploadedBytes)
            existing.isExpensive = existing.isExpensive || pending.isExpensive
            existing.isConstrained = existing.isConstrained || pending.isConstrained
            existing.lastObservedAt = max(existing.lastObservedAt, pending.lastObservedAt)
        } else {
            context.insert(
                UsageBucketEntity(
                    bucketKey: pending.bucketKey,
                    identityKey: pending.identityKey,
                    networkName: pending.networkName,
                    connectionKindRaw: pending.connectionKind.rawValue,
                    interfaceName: pending.interfaceName,
                    startedAt: pending.startedAt,
                    endedAt: pending.endedAt,
                    downloadedBytes: try persistedValue(pending.downloadedBytes),
                    uploadedBytes: try persistedValue(pending.uploadedBytes),
                    isExpensive: pending.isExpensive,
                    isConstrained: pending.isConstrained,
                    lastObservedAt: pending.lastObservedAt
                )
            )
        }
    }

    private func upsertCoverage(_ pending: PendingCoverage) throws {
        let key = pending.bucketKey
        var descriptor = FetchDescriptor<EvidenceCoverageEntity>(
            predicate: #Predicate<EvidenceCoverageEntity> { bucket in
                bucket.bucketKey == key
            }
        )
        descriptor.fetchLimit = 1

        if let existing = try context.fetch(descriptor).first {
            existing.activeSeconds += pending.activeSeconds
            existing.healthySeconds += pending.healthySeconds
            existing.metadataDegradedSeconds += pending.metadataDegradedSeconds
            existing.trackingDegradedSeconds += pending.trackingDegradedSeconds
            existing.unknownNetworkSeconds += pending.unknownNetworkSeconds
            existing.lastObservedAt = max(existing.lastObservedAt, pending.lastObservedAt)
        } else {
            context.insert(
                EvidenceCoverageEntity(
                    bucketKey: pending.bucketKey,
                    startedAt: pending.startedAt,
                    endedAt: pending.endedAt,
                    activeSeconds: pending.activeSeconds,
                    healthySeconds: pending.healthySeconds,
                    metadataDegradedSeconds: pending.metadataDegradedSeconds,
                    trackingDegradedSeconds: pending.trackingDegradedSeconds,
                    unknownNetworkSeconds: pending.unknownNetworkSeconds,
                    lastObservedAt: pending.lastObservedAt
                )
            )
        }
    }

    private func profilePresentationNames() throws -> [String: String] {
        let profiles = try context.fetch(FetchDescriptor<NetworkProfileEntity>())
        return Dictionary(uniqueKeysWithValues: profiles.map { profile in
            (profile.identityKey, profile.displayAlias ?? profile.networkName)
        })
    }

    private func snapshot(
        from entity: UsageBucketEntity,
        presentationNames: [String: String]
    ) -> UsageBucketSnapshot? {
        guard entity.downloadedBytes >= 0, entity.uploadedBytes >= 0 else { return nil }

        return UsageBucketSnapshot(
            bucketKey: entity.bucketKey,
            identityKey: entity.identityKey,
            networkName: presentationNames[entity.identityKey] ?? entity.networkName,
            connectionKind: NetworkConnectionKind(rawValue: entity.connectionKindRaw) ?? .other,
            interfaceName: entity.interfaceName,
            startedAt: entity.startedAt,
            endedAt: entity.endedAt,
            downloadedBytes: UInt64(entity.downloadedBytes),
            uploadedBytes: UInt64(entity.uploadedBytes),
            isExpensive: entity.isExpensive,
            isConstrained: entity.isConstrained,
            lastObservedAt: entity.lastObservedAt
        )
    }

    private func coverageSnapshot(from entity: EvidenceCoverageEntity) -> EvidenceCoverageSnapshot {
        EvidenceCoverageSnapshot(
            bucketKey: entity.bucketKey,
            startedAt: entity.startedAt,
            endedAt: entity.endedAt,
            activeSeconds: entity.activeSeconds,
            healthySeconds: entity.healthySeconds,
            metadataDegradedSeconds: entity.metadataDegradedSeconds,
            trackingDegradedSeconds: entity.trackingDegradedSeconds,
            unknownNetworkSeconds: entity.unknownNetworkSeconds,
            lastObservedAt: entity.lastObservedAt
        )
    }

    private func overlaps(_ pending: PendingBucket, period: DateInterval?) -> Bool {
        guard let period else { return true }
        return pending.startedAt < period.end && pending.endedAt > period.start
    }

    private func overlaps(_ pending: PendingCoverage, period: DateInterval?) -> Bool {
        guard let period else { return true }
        return pending.startedAt < period.end && pending.endedAt > period.start
    }

    private func bucketStart(containing date: Date) -> Date {
        let timestamp = date.timeIntervalSince1970
        let aligned = floor(timestamp / bucketInterval) * bucketInterval
        return Date(timeIntervalSince1970: aligned)
    }

    private func makeBucketKey(identityKey: String, interfaceName: String, startedAt: Date) -> String {
        let encodedIdentity = Data(identityKey.utf8).base64EncodedString()
        let timestamp = Int64(startedAt.timeIntervalSince1970)
        return "\(encodedIdentity):\(interfaceName):\(timestamp)"
    }

    private func persistedValue(_ value: UInt64) throws -> Int64 {
        guard value <= UInt64(Int64.max) else { throw StoreError.byteCounterOverflow }
        return Int64(value)
    }

    private func adding(_ delta: UInt64, to existing: Int64) throws -> Int64 {
        guard existing >= 0 else { throw StoreError.byteCounterOverflow }
        let deltaValue = try persistedValue(delta)
        let (sum, overflow) = existing.addingReportingOverflow(deltaValue)
        guard !overflow else { throw StoreError.byteCounterOverflow }
        return sum
    }

    private func saturatedAdd(_ lhs: UInt64, _ rhs: UInt64) -> UInt64 {
        let (value, overflow) = lhs.addingReportingOverflow(rhs)
        return overflow ? UInt64.max : value
    }
}
#endif
