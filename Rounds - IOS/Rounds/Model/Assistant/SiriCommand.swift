import Foundation

/// One thing Rounds can do through Siri, with phrases that work, for the Siri commands guide.
/// Phrases mirror `RoundsShortcuts` (App/Intents), which registers them with Siri.
struct SiriCommand: Identifiable, Sendable {
    let id: String
    let title: String
    let detail: String
    let phrases: [String]

    /// One-breath commands: say one of these, naming a topic where the phrase has one.
    static let direct: [SiriCommand] = [
        SiriCommand(id: "next", title: "Start a patient", detail: "Opens Rounds and admits your next patient.",
                    phrases: ["Next patient in Rounds", "Start my next patient in Rounds", "Start a surgery patient in Rounds"]),
        SiriCommand(id: "queue", title: "Queue a patient for later", detail: "Admits one in the background and notifies you when they're waiting.",
                    phrases: ["Queue my next patient in Rounds", "Queue a cardiology patient in Rounds"]),
        SiriCommand(id: "cards", title: "Make flashcards", detail: "Writes 20 cards without opening the app.",
                    phrases: ["Make flashcards in Rounds", "Make GI cards in Rounds"]),
        SiriCommand(id: "mistakes", title: "Review your mistakes", detail: "Cards from your wrong diagnoses and missed red flags.",
                    phrases: ["Review my mistakes in Rounds"]),
        SiriCommand(id: "streak", title: "Check your streak", detail: "Your streak and how long is left to keep it.",
                    phrases: ["What's my streak in Rounds", "Check my Rounds streak"]),
    ]

    /// Ask Rounds: Siri asks what to do, and the student answers in their own words, for the same
    /// actions as above.
    static let ask = SiriCommand(
        id: "ask", title: "Say it your way",
        detail: "Say \"Ask Rounds\". When Siri asks what to do, ask for any of the above in your own words.",
        phrases: ["Get a kidney patient ready for after dinner", "Drill me on 30 lung flashcards",
                  "Go over the stuff I messed up", "How many days in a row have I done this?"])

    /// Topic names Siri understands, one per topic, plus the shorthand students use.
    static var topicNames: [String] {
        CommandKeywords.topics.map { topic in
            let short = topic.words.first { $0.count <= 5 && $0 != topic.focus.label.lowercased() }
            return short.map { "\(topic.focus.label) (\($0))" } ?? topic.focus.label
        }
    }

    /// Setting up "every day at 6 PM, queue a patient" in the Shortcuts app.
    static let automationSteps = [
        "Open the Shortcuts app and go to Automation.",
        "Tap +, choose Time of Day, and set 6:00 PM, daily.",
        "Choose Run Immediately.",
        "Add the Rounds action Queue Patient, or Ask Rounds with what you want.",
    ]
}
