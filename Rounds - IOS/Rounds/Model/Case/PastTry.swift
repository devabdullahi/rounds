import Foundation

/// One graded attempt at a patient, as the student left it: what they answered, what they did, and
/// how it was graded. Shown from "Previous tries" so a revisit can be compared with last time.
struct PastTry: Identifiable, Hashable {
    let id: String
    let submittedAt: Date
    let score: Int
    let verdict: String
    let diagnosisCorrect: Bool
    /// The case's real diagnosis.
    let actualDiagnosis: String
    /// What the student committed to; empty when they submitted none.
    let yourDiagnosis: String
    let differential: [String]
    let plan: String
    /// Tests in the order they were ordered, by name.
    let testsOrdered: [String]
    /// Exam steps done, by title.
    let examDone: [String]
    let feedback: [Feedback]
    let missedRedFlags: [Miss]
    let examMode: Bool

    static func == (a: PastTry, b: PastTry) -> Bool { a.id == b.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

#if DEBUG
extension PastTry {
    /// Two fictional tries at the `debugSample` patient (recurrent mouth sores): a miss, then the right call.
    static let debugSamples = [
        PastTry(id: "debug-2", submittedAt: .now.addingTimeInterval(-2 * 86_400), score: 86,
                verdict: "Right diagnosis, incomplete path", diagnosisCorrect: true,
                actualDiagnosis: "Recurrent aphthous stomatitis", yourDiagnosis: "Aphthous ulcers",
                differential: ["Herpetic gingivostomatitis", "Behçet disease"],
                plan: "Topical steroid paste, avoid sharp foods, check CBC, iron studies, B12 and folate.",
                testsOrdered: ["CBC", "Iron studies", "Vitamin B12"], examDone: ["Oral cavity", "Lymph nodes"],
                feedback: [Feedback(tone: .good, title: "Focused history", detail: "You pinned down timing, recurrence and stress as a trigger."),
                           Feedback(tone: .miss, title: "Bowel symptoms not asked", detail: "Recurrent mouth ulcers can come with Crohn's or celiac disease.",
                                    coversMiss: "Bowel symptoms")],
                missedRedFlags: [Miss(flag: "Bowel symptoms", why: "Mouth ulcers can be the first sign of inflammatory bowel disease.")],
                examMode: false),
        PastTry(id: "debug-1", submittedAt: .now.addingTimeInterval(-9 * 86_400), score: 41,
                verdict: "Missed diagnosis", diagnosisCorrect: false,
                actualDiagnosis: "Recurrent aphthous stomatitis", yourDiagnosis: "Oral herpes",
                differential: ["Hand-foot-mouth disease"], plan: "Acyclovir.",
                testsOrdered: ["HSV PCR"], examDone: ["Oral cavity"],
                feedback: [Feedback(tone: .miss, title: "The diagnosis was Recurrent aphthous stomatitis",
                                    detail: "Round shallow ulcers with a red rim, recurring in crops, without vesicles or fever.")],
                missedRedFlags: [], examMode: true),
    ]
}
#endif
