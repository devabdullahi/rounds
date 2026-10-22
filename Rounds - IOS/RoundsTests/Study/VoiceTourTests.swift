import Testing
@testable import Rounds

/// The voice tour waits on the student, teaches cutting in, and ends after the second answer.
struct VoiceTourTests {
    @Test func theTourWaitsForTapsAndTeachesInterrupting() {
        var tour = VoiceTour()
        #expect(tour.toSay == VoiceTour.lines[0].question)
        let sent = tour.tap()                    // send the first question
        #expect(sent)
        #expect(tour.phase == .thinking)
        let early = tour.tap()                   // nothing to do while she thinks
        #expect(!early)
        tour.patientAnswers()
        #expect(tour.phase == .patient)
        tour.patientFinished()                   // the first answer never ends on its own
        #expect(tour.phase == .patient)
        #expect(tour.toSay == VoiceTour.lines[1].question)
        let cut = tour.tap()                     // cut her off
        #expect(cut)
        #expect(tour.phase == .listening && tour.cutIn)
        let second = tour.tap()                  // send the second question
        #expect(second)
        tour.patientAnswers()
        tour.patientFinished()
        #expect(tour.phase == .done)
        #expect(tour.toSay == nil)
        #expect(tour.shown.map(\.reply) == VoiceTour.lines.map(\.reply))
    }

    @Test func aQuestionShowsBeforeItsAnswer() {
        var tour = VoiceTour()
        tour.tap()
        #expect(tour.shown.count == 1 && tour.shown[0].reply == nil)
    }
}
