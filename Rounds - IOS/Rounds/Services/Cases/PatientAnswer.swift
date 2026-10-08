import Foundation

/// The patient's reply to one question.
struct PatientAnswer: Sendable {
    let reply: String
    /// Newly revealed topics (empty in exam mode, where labels stay hidden).
    let revealed: [(id: String, label: String)]
    /// Every fact id revealed so far, so suggestions can hide what's been covered.
    let revealedIDs: [String]
    let coverage: (got: Int, total: Int)
}
