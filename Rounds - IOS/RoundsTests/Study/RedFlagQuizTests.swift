import Testing
@testable import Rounds

struct RedFlagQuizTests {
    /// The quiz only works with exactly one red flag, and it's the cardiac one.
    @Test func chestPainHasExactlyOneRedFlag() {
        let quiz = RedFlagQuiz.chestPain
        #expect(quiz.options.filter(\.isRedFlag).count == 1)
        #expect(quiz.answer?.text.contains("jaw") == true)
        #expect(Set(quiz.options.map(\.id)).count == quiz.options.count)
    }
}
