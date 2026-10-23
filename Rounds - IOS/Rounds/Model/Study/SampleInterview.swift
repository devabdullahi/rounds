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

    /// A 34-year-old with belly pain since last night.
    static let bellyPain = SampleInterview(
        initials: "DR", patient: "Dana, 34", complaint: "Belly pain since last night",
        exchanges: [
            Exchange(question: "When did it start?",
                     reply: "Last night, around dinner. It was a dull ache near my belly button at first.",
                     reveals: "Onset"),
            Exchange(question: "Has the pain moved?",
                     reply: "Yeah, this morning it moved down here, to the lower right. It's sharper now.",
                     reveals: "Migration"),
            Exchange(question: "Any nausea or fever?",
                     reply: "I threw up once, and I've felt warm all morning.",
                     reveals: "Associated symptoms"),
        ])

    /// The exchanges asked so far, in the order the student asked them.
    func asked(_ ids: [String]) -> [Exchange] {
        ids.compactMap { id in exchanges.first { $0.id == id } }
    }
}
