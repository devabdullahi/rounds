import Testing
@testable import Rounds

struct StudyStruggleTests {
    @Test func picksRoundTripInListOrder() {
        let picks: Set<StudyStruggle> = [.timing, .whatToAsk]
        let stored = StudyStruggle.encode(picks)
        #expect(stored == "whatToAsk,timing")
        #expect(StudyStruggle.decode(stored) == picks)
    }

    @Test func emptyAndUnknownValuesReadAsNoPicks() {
        #expect(StudyStruggle.decode("").isEmpty)
        #expect(StudyStruggle.decode("nope,tests") == [.tests])
    }
}
