import Foundation

/// A condition from a standard list, e.g. "STEMI, inferior wall" with its ICD-10-CM code.
struct ConditionMatch: Identifiable, Hashable, Sendable {
    let code: String            // ICD-10-CM
    let name: String
    let synonyms: [String]
    var id: String { code }
}
