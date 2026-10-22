import Foundation

/// The onboarding taste of an interview: a fictional patient, three questions a student might ask,
/// and the scripted answer to each, with the history topic it uncovers. Scripted, so it runs before
/// there's an account or AI consent, and sends nothing anywhere. Pure, so the script is tested.
struct SampleInterview: Equatable {
    struct Exchange: Equatable, Identifiable {
        let question: String
        let reply: String
        /// The history topic the reply uncovers, shown as a chip like in a real case.
        let reveals: String
        var id: String { question }
    }

    let initials: String
    let patient: String
    let complaint: String
    let exchanges: [Exchange]

    /// A 24-year-old with a sore throat: strep throat, the most basic case there is (four classic
    /// signs, one bedside test), so the first patient a student meets is one any year can work up.
    static let soreThroat = SampleInterview(
        initials: "DR", patient: "Dana, 24", complaint: "Sore throat for two days",
        exchanges: [
            Exchange(question: "When did it start?",
                     reply: "Two days ago. It really hurts to swallow.",
                     reveals: "Onset"),
            Exchange(question: "Any fever or cough?",
                     reply: "I've felt hot and shivery. No cough at all.",
                     reveals: "Fever, no cough"),
            Exchange(question: "Anyone sick around you?",
                     reply: "My roommate had strep last week.",
                     reveals: "Sick contact"),
        ])

    /// The exchanges asked so far, in the order the student asked them.
    func asked(_ ids: [String]) -> [Exchange] {
        ids.compactMap { id in exchanges.first { $0.id == id } }
    }
}
