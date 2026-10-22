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

    /// A 24-year-old with burning when she pees: an uncomplicated bladder infection, the most
    /// basic case there is (three classic symptoms, one bedside test), so the first patient a
    /// student meets is one any year can work up.
    static let burning = SampleInterview(
        initials: "DR", patient: "Dana, 24", complaint: "Burning when she pees",
        exchanges: [
            Exchange(question: "When did it start?",
                     reply: "Two days ago. It burns every time I pee.",
                     reveals: "Onset"),
            Exchange(question: "How often are you going?",
                     reply: "All the time. I go, and ten minutes later I need to go again.",
                     reveals: "Frequency"),
            Exchange(question: "Any fever or back pain?",
                     reply: "No fever, and my back feels fine.",
                     reveals: "Red flags"),
        ])

    /// The exchanges asked so far, in the order the student asked them.
    func asked(_ ids: [String]) -> [Exchange] {
        ids.compactMap { id in exchanges.first { $0.id == id } }
    }
}
