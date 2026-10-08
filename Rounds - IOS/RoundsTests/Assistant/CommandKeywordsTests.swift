import Testing
@testable import Rounds

@Suite("Ask Rounds keywords")
struct CommandKeywordsTests {
    @Test(arguments: [
        ("give me my next patient", RoundsCommand.startPatient(nil)),
        ("start a surgery case", .startPatient(.rotation(.surgery))),
        ("queue a hard heme patient for tonight", .queuePatient(.system(.blood))),
        ("line up a peds patient", .queuePatient(.rotation(.pediatrics))),
        ("quiz me on 10 cardiology cards", .makeCards(.system(.cardiovascular), count: 10)),
        ("make me some GI flashcards", .makeCards(.system(.gastrointestinal), count: nil)),
        ("make twenty OB/GYN cards", .makeCards(.rotation(.obgyn), count: 20)),
        ("cards from my mistakes", .reviewMistakes(count: nil)),
        ("what did I get wrong", .reviewMistakes(count: nil)),
        ("how's my streak", .streak),
        ("family medicine patient please", .startPatient(.rotation(.familyMedicine))),
        ("can you get a kidney patient ready for me after dinner", .queuePatient(.system(.renal))),
        ("I want to drill some lung flashcards, like thirty", .makeCards(.system(.respiratory), count: 30)),
        ("go over the stuff I messed up", .reviewMistakes(count: nil)),
        ("how many days in a row have I done this", .streak),
        ("throw me a sick kid", .startPatient(.rotation(.pediatrics))),
        ("I'm ready for a patient", .startPatient(nil)),
        ("what's the weather", .unclear),
    ])
    func readsTheRequest(request: String, expected: RoundsCommand) {
        #expect(CommandKeywords.parse(request) == expected)
    }

    @Test func countsSnapToDeckSizes() {
        #expect(CommandKeywords.count(in: "make 15 cards") == 10 || CommandKeywords.count(in: "make 15 cards") == 20)
        #expect(CommandKeywords.count(in: "make 45 cards") == 50)
        #expect(CommandKeywords.count(in: "make cards") == nil)
    }

    @Test func everyTopicIsCovered() {
        let covered = Set(CommandKeywords.topics.map(\.focus))
        #expect(Clerkship.allCases.allSatisfy { covered.contains(.rotation($0)) })
        #expect(OrganSystem.allCases.allSatisfy { covered.contains(.system($0)) })
    }

    @Test func iAmIsNotInternalMedicine() {
        #expect(CommandKeywords.topic(in: "I'm ready for a patient") == nil)
    }
}
