import Foundation

struct ClinicalCase: Identifiable, Hashable {
    let bed: String
    let name: String
    let age: Int
    let sex: String
    let setting: String
    let quote: String
    let demeanor: String
    let complaint: String
    let vitals: [Vital]
    let task: String
    let minutes: Int
    let budget: Int
    let suggestedQuestions: [SuggestedQuestion]
    let exam: [ExamManeuver]
    let tests: [Investigation]
    let clerkship: Clerkship?
    let system: OrganSystem?
    /// How many key history topics there are, for the coverage meter.
    let keyHistoryTotal: Int

    var id: String { bed }
    /// What the student calls the patient in voice prompts: the first name, skipping a nickname
    /// ("Margaret \"Maggie\" Ellison" → "Margaret").
    var firstName: String { nameWords.first.map(String.init) ?? name }

    /// First letters of the first and last names, skipping nicknames and punctuation
    /// ("Margaret \"Maggie\" Ellison" → "ME").
    var initials: String {
        let words = nameWords
        let letters = [words.first, words.count > 1 ? words.last : nil].compactMap { $0?.first(where: \.isLetter) }
        return String(letters).uppercased()
    }

    /// The name's words without nicknames in quotes or parentheses.
    private var nameWords: [Substring] {
        name.split(separator: " ").filter { !$0.hasPrefix("\"") && !$0.hasPrefix("(") }
    }
}
