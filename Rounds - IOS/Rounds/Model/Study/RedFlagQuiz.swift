import Foundation

/// The onboarding mini-case: four things a chest-pain patient says, one of them the red flag a
/// student should catch. Pure, so which answer counts is tested.
struct RedFlagQuiz: Equatable {
    struct Option: Equatable, Identifiable {
        let text: String
        let isRedFlag: Bool
        var id: String { text }
    }

    let patient: String
    let options: [Option]

    /// A 58-year-old with chest tightness: only pain spreading to the jaw with sweating points at the heart.
    static let chestPain = RedFlagQuiz(patient: "Ray, 58 · chest tightness", options: [
        Option(text: "\u{201C}It's sore when I press on my ribs.\u{201D}", isRedFlag: false),
        Option(text: "\u{201C}It goes up into my jaw, and I'm sweaty.\u{201D}", isRedFlag: true),
        Option(text: "\u{201C}It twinges when I twist.\u{201D}", isRedFlag: false),
        Option(text: "\u{201C}It started after a coughing fit.\u{201D}", isRedFlag: false),
    ])

    /// The option to show as correct once the student has picked.
    var answer: Option? { options.first(where: \.isRedFlag) }
}
