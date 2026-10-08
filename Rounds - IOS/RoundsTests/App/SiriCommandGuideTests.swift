import Testing
@testable import Rounds

@Suite("Siri commands guide")
struct SiriCommandGuideTests {
    @Test func everyTopicIsListed() {
        #expect(SiriCommand.topicNames.count == Clerkship.allCases.count + OrganSystem.allCases.count)
        #expect(SiriCommand.topicNames.count == IntentTopic.allCases.count)
    }

    /// Every phrase the guide shows names the app, as Siri requires.
    @Test func everyPhraseNamesRounds() {
        #expect(SiriCommand.direct.flatMap(\.phrases).allSatisfy { $0.contains("Rounds") })
    }
}
