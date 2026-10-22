import Foundation

/// The rest of onboarding's sample case, after the interview (`SampleInterview`): the exam, the
/// tests and the debrief, scripted so they run before there's an account or AI consent and send
/// nothing anywhere. Pure, so the script and the scoring are tested.
struct SampleWorkup: Equatable {
    /// One exam row: what the student does, and what they find.
    struct Maneuver: Equatable, Identifiable {
        let id: String
        let title: String
        let finding: String
        let isAbnormal: Bool
    }

    /// One orderable test and its result.
    struct Test: Equatable, Identifiable {
        let id: String
        let name: String
        let kind: String
        let result: String
        let isAbnormal: Bool
    }

    /// A line of the attending's feedback.
    struct Feedback: Equatable {
        let title: String
        let detail: String
    }

    let patient: String
    let mood: String
    let maneuvers: [Maneuver]
    let tests: [Test]
    /// The diagnoses offered, the right one first; the screen shuffles nothing, so order is fixed.
    let diagnoses: [String]
    let answer: String
    let good: Feedback
    let miss: Feedback

    /// How many exam rows must be done, and tests ordered, before the student may move on.
    static let examsNeeded = 4
    static let testsNeeded = 2

    /// Strep throat: four classic signs and one bedside test, so any year can work it up.
    static let soreThroat = SampleWorkup(
        patient: "Dana Reyes, 24", mood: "Tired, wincing when she swallows",
        maneuvers: [
            Maneuver(id: "vitals", title: "Take her temperature and vitals",
                     finding: "101.8 °F, heart rate 96. She has a fever.", isAbnormal: true),
            Maneuver(id: "throat", title: "Look in her throat",
                     finding: "Red, swollen tonsils with white patches.", isAbnormal: true),
            Maneuver(id: "neck", title: "Feel the front of her neck",
                     finding: "Tender, swollen lymph nodes.", isAbnormal: true),
            Maneuver(id: "lungs", title: "Listen to her lungs",
                     finding: "Clear on both sides.", isAbnormal: false),
        ],
        tests: [
            Test(id: "strep", name: "Rapid strep test", kind: "Bedside", result: "Positive.", isAbnormal: true),
            Test(id: "mono", name: "Monospot", kind: "Blood", result: "Negative.", isAbnormal: false),
            Test(id: "cbc", name: "CBC", kind: "Blood", result: "WBC 13.1 ×10³/µL, high.", isAbnormal: true),
            Test(id: "culture", name: "Throat culture", kind: "Lab", result: "Result in 2 days.", isAbnormal: false),
        ],
        diagnoses: ["Strep throat", "Viral sore throat", "Mono"],
        answer: "Strep throat",
        good: Feedback(title: "All four signs found", detail: "Fever, no cough, white patches, sore neck nodes."),
        miss: Feedback(title: "Allergies not asked", detail: "Check for a penicillin allergy before you treat. In real cases, misses like this become cards."))

    /// The score out of 100 for a pick: the workup earns most of it, the right call the rest.
    func score(for pick: String) -> Int { pick == answer ? 82 : 61 }

    /// The line under the diagnosis: a check for the right call, otherwise why it points here.
    func verdict(for pick: String) -> String {
        pick == answer ? "You said \(answer)" : "You said \(pick). Fever, no cough, white patches and a positive rapid test point to strep."
    }

    /// What the share sheet sends.
    func shareText(for pick: String) -> String {
        "I worked up my first patient on Rounds and scored \(score(for: pick))/100."
    }
}
