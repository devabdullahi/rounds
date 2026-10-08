import SwiftUI
import Observation

/// The server's verdict on a submitted attempt.
struct Grade {
    let score: Int
    let diagnosisCorrect: Bool
    /// The case's actual diagnosis, revealed only now.
    let diagnosis: String
    let verdict: String
    let ratingDelta: Int
    /// The student's rating after this case.
    let rating: Int
    let feedback: [Feedback]
    let missedRedFlags: [Miss]
}
