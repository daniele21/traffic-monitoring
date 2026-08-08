#if os(macOS)
import SwiftData

@MainActor
enum PersistenceBootstrap {
    /// M0 scaffold only. M3 supplies the concrete schema and owns container creation.
    static func makeContainer(for schema: Schema, inMemory: Bool = false) throws -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: inMemory)
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
#endif
