import Foundation

struct TrackingConfiguration: Sendable {
    var sampleInterval: Duration = .seconds(2)
    var persistenceCheckpointInterval: Duration = .seconds(15)
    var analyticsBucketInterval: Duration = .seconds(300)
    var deltaValidation = DeltaValidationConfiguration()

    static let `default` = TrackingConfiguration()
}
