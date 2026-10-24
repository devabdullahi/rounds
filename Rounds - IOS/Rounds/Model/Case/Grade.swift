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
    /// Teaching summary of the actual condition. Nil on older grades, which predate it.
    var about: ConditionAbout? = nil
    /// What else this presentation could have been, marked against the student's list. Empty on older grades.
    var differential: [DifferentialReview] = []
    /// Conditions the student listed that aren't usual considerations for this case.
    var yourExtras: [String] = []
    /// The case taught for the student's exam. Nil without a goal, or on older grades.
    var lens: ExamLens? = nil
    /// Points earned out of the points available for each part. Empty on grades older than the breakdown.
    var breakdown: [ScoreCategory: Points] = [:]
    /// What the workup earned on its own (everything but the diagnosis), out of its most. Nil on
    /// older grades.
    var workupPoints: (got: Int, max: Int)? = nil
    /// A right diagnosis lifted the score to the passing floor.
    var floorApplied = false

    /// Under the score when the floor lifted it: the workup's own points, so a lucky call doesn't
    /// read like a strong workup.
    var floorNote: String? {
        guard floorApplied, let workupPoints else { return nil }
        return "Right call. Your workup earned \(workupPoints.got) of \(workupPoints.max)."
    }
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
                            coversMiss: "Bowel symptoms", isFocus: true)],
        missedRedFlags: [Miss(flag: "Bowel symptoms", why: "Mouth ulcers can be the first sign of inflammatory bowel disease.")],
        about: ConditionAbout(
            summaryPoints: ["Common, benign ulcers of the non-keratinized mouth lining that recur in crops.",
                            "Usually starts in childhood or the teens; most heal in 7 to 14 days without scarring.",
                            "A diagnosis of exclusion: look for systemic disease when ulcers are severe or come with other signs."],
            symptoms: ["Painful round ulcers", "Yellow-gray base, red rim", "Tingling before onset", "No fever"],
            riskFactors: ["Stress", "Minor mouth trauma", "Family history", "Iron, B12 or folate deficiency", "Celiac or Crohn's disease"]),
        differential: [
            DifferentialReview(name: "Herpetic gingivostomatitis", mustNotMiss: false,
                               why: "Painful oral ulcers that can recur.",
                               tellApart: ["Clustered vesicles that burst into ulcers", "Fever and swollen, bleeding gums on first episode", "Recurrences favor the lip border"],
                               inYours: true),
            DifferentialReview(name: "Squamous cell carcinoma of the mouth", mustNotMiss: true,
                               why: "A mouth sore that won't heal must be cancer until shown otherwise.",
                               tellApart: ["Single ulcer lasting over 3 weeks", "Firm, raised edges", "Tobacco or heavy alcohol use"],
                               inYours: false),
            DifferentialReview(name: "Behçet disease", mustNotMiss: false,
                               why: "Recurrent oral ulcers are its hallmark.",
                               tellApart: ["Genital ulcers", "Eye inflammation", "Skin lesions or positive pathergy test"],
                               inYours: false),
            DifferentialReview(name: "Hand-foot-mouth disease", mustNotMiss: false,
                               why: "Causes several small oral ulcers at once.",
                               tellApart: ["Mostly young children", "Rash on palms and soles", "One self-limited episode with fever"],
                               inYours: false),
            DifferentialReview(name: "Oral lichen planus", mustNotMiss: false,
                               why: "Can cause painful erosions inside the cheeks.",
                               tellApart: ["Lacy white streaks", "Chronic rather than coming and going", "Usually middle-aged adults"],
                               inYours: false)],
        yourExtras: ["Scurvy"],
        lens: ExamLens(title: "For Step 2 CK: next best steps",
                       points: ["Treat symptoms first: topical steroid or anesthetic rinse",
                                "Check CBC, iron, B12 and folate when ulcers are frequent or severe",
                                "Biopsy any single ulcer that lasts more than 3 weeks"]),
        breakdown: [.diagnosis: Points(got: 35, max: 35), .history: Points(got: 17, max: 20), .exam: Points(got: 12, max: 15),
                    .redFlags: Points(got: 5, max: 10), .tests: Points(got: 10, max: 10), .plan: Points(got: 7, max: 10)])
}
#endif
