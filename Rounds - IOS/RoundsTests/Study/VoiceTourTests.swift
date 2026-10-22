import Testing
@testable import Rounds

/// The voice tour waits for real speech, shows the student's own words, teaches cutting in, and
/// ends after the second answer.
struct VoiceTourTests {
    @Test func theTourWaitsForSpeechAndTeachesInterrupting() {
        var tour = VoiceTour()
        #expect(tour.toSay == VoiceTour.lines[0].question)
        let silent = tour.send("   ")
        #expect(!silent)   // silence sends nothing
        let sentFirst = tour.send("when did it start")
        #expect(sentFirst)   // the first question, in their words
        #expect(tour.phase == .thinking)
        let early = tour.send("hello again")
        #expect(!early)   // nothing to do while she thinks
        tour.patientAnswers()
        #expect(tour.phase == .patient)
        tour.patientFinished()   // the first answer never ends on its own
        #expect(tour.phase == .patient)
        #expect(tour.toSay == VoiceTour.lines[1].question)
        let cut = tour.interrupt()
        #expect(cut)   // talking over her cuts her off
        #expect(tour.phase == .listening && tour.cutIn)
        let sentSecond = tour.send("any fever or cough")
        #expect(sentSecond)
        tour.patientAnswers()
        let lateCut = tour.interrupt()
        #expect(!lateCut)   // only the first answer teaches cutting in
        tour.patientFinished()
        #expect(tour.phase == .done)
        #expect(tour.toSay == nil)
        #expect(tour.shown.map(\.question) == ["when did it start", "any fever or cough"])
        #expect(tour.shown.map(\.reply) == VoiceTour.lines.map(\.reply))
    }

    @Test func aQuestionShowsBeforeItsAnswer() {
        var tour = VoiceTour()
        tour.send("when did it start")
        #expect(tour.shown.count == 1 && tour.shown[0].reply == nil)
    }

    @Test(arguments: [
        ("", 5.0, false),                                // nothing heard
        ("um", 5.0, false),                              // one word is not a question
        ("when did it start", 0.3, false),               // still mid-sentence
        ("when did it start", 1.0, true),                // words, then a pause
    ])
    func aTurnEndsOnWordsThenAPause(heard: String, quiet: Double, over: Bool) {
        #expect(VoiceTour.turnIsOver(heard: heard, quietFor: quiet) == over)
    }
}
