import Foundation

/// Background facts for drafting a case. Authoring only: never shown to students as-is.
struct DiseaseFacts: Hashable, Sendable {
    let conditionCode: String
    let symptoms: [String]
    let riskFactors: [String]
    let redFlags: [String]
}
