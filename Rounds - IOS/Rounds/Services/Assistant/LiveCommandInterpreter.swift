import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Apple's on-device model where it's available (iOS 26 with Apple Intelligence on), keywords
/// everywhere else and whenever the model can't answer. Nothing leaves the phone either way.
struct LiveCommandInterpreter: CommandInterpreter {
    func interpret(_ request: String) async -> RoundsCommand {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *), SystemLanguageModel.default.availability == .available,
           let command = await OnDeviceReader.read(request), command != .unclear {
            return command
        }
        #endif
        return CommandKeywords.parse(request)
    }
}

#if canImport(FoundationModels)
/// The on-device model's half: guided generation into a fixed shape, so it can only pick from
/// Rounds' actions and topics, never invent one.
@available(iOS 26.0, *)
private enum OnDeviceReader {
    static let actions = ["start_patient", "queue_patient", "make_cards", "review_mistakes", "streak", "unclear"]
    static let topicIDs = CommandKeywords.topics.map(\.focus.stored)

    @Generable
    struct Reading {
        @Guide(description: "What the student wants Rounds to do.", .anyOf(OnDeviceReader.actions))
        var action: String
        @Guide(description: "The topic id they named, or none.", .anyOf(OnDeviceReader.topicIDs + ["none"]))
        var topic: String
        @Guide(description: "How many flashcards they asked for, or none.", .anyOf(["10", "20", "30", "50", "none"]))
        var count: String
    }

    static var instructions: String {
        let topics = CommandKeywords.topics.map { "\($0.focus.stored): \($0.focus.label) (\($0.words.joined(separator: ", ")))" }
        return """
        You route a medical student's spoken request to one action in Rounds, a practice app with fictional patients.
        Actions:
        - start_patient: begin a patient case now ("next patient", "give me a case").
        - queue_patient: have a patient waiting for later without starting it ("queue", "line one up").
        - make_cards: generate a flashcard deck.
        - review_mistakes: flashcards from their own wrong diagnoses and missed red flags.
        - streak: how many days in a row they've practiced.
        - unclear: anything else.
        Topic ids, with words students use for them:
        \(topics.joined(separator: "\n"))
        Pick a topic only if the request names one. Pick a card count only if it says a number.
        """
    }

    static func read(_ request: String) async -> RoundsCommand? {
        let session = LanguageModelSession(instructions: instructions)
        guard let reading = try? await session.respond(to: request, generating: Reading.self).content else { return nil }
        let topic = reading.topic == "none" ? nil : StudyFocus(stored: reading.topic)
        let count = Int(reading.count)
        switch reading.action {
        case "start_patient": return .startPatient(topic)
        case "queue_patient": return .queuePatient(topic)
        case "make_cards": return .makeCards(topic, count: count)
        case "review_mistakes": return .reviewMistakes(count: count)
        case "streak": return .streak
        default: return .unclear
        }
    }
}
#endif
