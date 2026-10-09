import Foundation

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
    /// A fictional grade for the `debrief-graded` screen, matching the `demo-interview` patient
    /// (recurrent mouth sores): the right call, with one thing missed.
    static let debugSample = Grade(
        score: 86, diagnosisCorrect: true, diagnosis: "Recurrent aphthous stomatitis",
        verdict: "Right call. You ruled out fever and spread before settling on it.", ratingDelta: 12, rating: 1312,
        feedback: [Feedback(tone: .good, title: "Focused history", detail: "You pinned down timing, recurrence and stress as a trigger."),
                   Feedback(tone: .miss, title: "Bowel symptoms not asked", detail: "Recurrent mouth ulcers can come with Crohn's or celiac disease; ask about diarrhea and weight loss.",
                            coversMiss: "Bowel symptoms")],
        missedRedFlags: [Miss(flag: "Bowel symptoms", why: "Mouth ulcers can be the first sign of inflammatory bowel disease.")])
}
#endif
