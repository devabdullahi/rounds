import Foundation

/// One entry in a ranked differential from a diagnosis engine. Authoring and QA only.
struct RankedDiagnosis: Hashable, Sendable {
    let name: String
    let probability: Double         // 0…1
}
