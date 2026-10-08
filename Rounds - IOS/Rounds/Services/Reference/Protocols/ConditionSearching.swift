import Foundation

protocol ConditionSearching: Sendable {
    /// Best matches for what the student has typed so far, most relevant first.
    func search(_ text: String, limit: Int) async throws -> [ConditionMatch]
}
