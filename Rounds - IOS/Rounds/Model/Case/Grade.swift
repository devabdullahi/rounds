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

#if DEBUG
extension Grade {
    /// A fictional, partly wrong grade for the `debrief-graded` screen.
    static let debugSample = Grade(
        score: 64, diagnosisCorrect: false, diagnosis: "Acute cholecystitis",
        verdict: "Close, but the fever and Murphy sign pointed past biliary colic.", ratingDelta: -8, rating: 1292,
        feedback: [Feedback(tone: .good, title: "Focused history", detail: "You pinned down the pain's timing and its link to meals."),
                   Feedback(tone: .miss, title: "Fever not followed up", detail: "A fever with right upper quadrant pain calls for a CBC and an ultrasound.", coversMiss: "Fever with RUQ pain")],
        missedRedFlags: [Miss(flag: "Fever with RUQ pain", why: "Suggests inflammation or infection, not simple colic.")])
}
#endif
