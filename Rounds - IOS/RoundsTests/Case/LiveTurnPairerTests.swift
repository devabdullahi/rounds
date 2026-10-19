import Testing
@testable import Rounds

/// A live call's question and answer arrive separately, in either order; each exchange logs once.
struct LiveTurnPairerTests {
    @Test func theStudentsWordsThenTheReplyMakeOneExchange() {
        var pairer = LiveTurnPairer()
        #expect(pairer.studentSaid("When did it start?") == nil)
        let turn = pairer.patientFinished("Last night.")
        #expect(turn?.question == "When did it start?")
        #expect(turn?.reply == "Last night.")
    }

    @Test func aReplyThatBeatsTheTranscriptWaitsForIt() {
        var pairer = LiveTurnPairer()
        #expect(pairer.patientFinished("Around my belly button.") == nil)
        let turn = pairer.studentSaid("Where is the pain?")
        #expect(turn?.question == "Where is the pain?")
        #expect(turn?.reply == "Around my belly button.")
    }

    @Test func twoUtterancesBeforeOneReplyAreOneQuestion() {
        var pairer = LiveTurnPairer()
        _ = pairer.studentSaid("Any fever?")
        _ = pairer.studentSaid("Or chills?")
        #expect(pairer.patientFinished("No, neither.")?.question == "Any fever? Or chills?")
    }

    @Test func eachExchangeIsLoggedOnce() {
        var pairer = LiveTurnPairer()
        _ = pairer.studentSaid("Hi")
        _ = pairer.patientFinished("Hello, doctor.")
        #expect(pairer.patientFinished("Anything else?") == nil)
        #expect(pairer.studentSaid("   ") == nil)
    }
}
