#if os(macOS)
import SwiftData

@MainActor
enum PersistenceBootstrap {
    static let schema = Schema([
        NetworkProfileEntity.self,
        UsageBucketEntity.self,
        EvidenceCoverageEntity.self
    ])

    static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: inMemory
        )
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
#endif
