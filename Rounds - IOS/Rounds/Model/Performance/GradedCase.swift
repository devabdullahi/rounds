import Foundation

/// One submitted, graded case, as the profile's stats and badges read it.
struct GradedCase: Identifiable, Hashable, Sendable {
    let id: String
    let submittedAt: Date
    let score: Int
    let diagnosisCorrect: Bool
    let missedRedFlags: Int
    let clerkship: Clerkship?
    let system: OrganSystem?
    /// Empty for cases graded before the server recorded a breakdown.
    let breakdown: [ScoreCategory: Points]
    /// Played in exam mode (no hints, findings hidden until the debrief).
    var examMode = false
    /// Played against a time limit.
    var timed = false
    /// The patient (case) this attempt was on, so a later attempt on the same patient can be found.
    var caseID: String?
}
