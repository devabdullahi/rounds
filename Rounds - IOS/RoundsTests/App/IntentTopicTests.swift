import Testing
@testable import Rounds

@Suite("Siri topics")
struct IntentTopicTests {
    @Test(arguments: IntentTopic.allCases)
    func everyTopicIsARealFocus(topic: IntentTopic) {
        #expect(topic.focus != .mix)
    }

    @Test func coversEveryRotationAndSystem() {
        let foci = Set(IntentTopic.allCases.map(\.focus.stored))
        #expect(Clerkship.allCases.allSatisfy { foci.contains(StudyFocus.rotation($0).stored) })
        #expect(OrganSystem.allCases.allSatisfy { foci.contains(StudyFocus.system($0).stored) })
    }

    @Test func deckSizesMatchWhatTheServerTakes() {
        #expect(CardCountOption.allCases.map(\.rawValue) == FlashcardStore.generateCounts)
    }
}
