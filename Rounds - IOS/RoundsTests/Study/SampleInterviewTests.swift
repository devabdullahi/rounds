import Testing
@testable import Rounds

/// The onboarding interview script: every question has an answer and a topic, and asked questions
/// come back in the order the student asked them.
struct SampleInterviewTests {
    @Test func everyQuestionHasAReplyAndATopic() {
        let interview = SampleInterview.burning
        #expect(interview.exchanges.count == 3)
        for exchange in interview.exchanges {
            #expect(!exchange.reply.isEmpty)
            #expect(!exchange.reveals.isEmpty)
        }
        #expect(Set(interview.exchanges.map(\.id)).count == interview.exchanges.count)
    }

    @Test func askedQuestionsKeepTheStudentsOrder() {
        let interview = SampleInterview.burning
        let ids = interview.exchanges.map(\.id)
        #expect(interview.asked([ids[2], ids[0]]).map(\.id) == [ids[2], ids[0]])
        #expect(interview.asked(["Something else"]).isEmpty)
    }
}
