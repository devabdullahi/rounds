import Foundation
import Testing
@testable import Rounds

/// The live voice model over a scripted call: starting, falling back, logging exchanges, ending.
@MainActor
struct LiveVoiceTests {
    struct Down: Error {}

    /// Collects what the model hands the case session.
    final class Log {
        var turns: [(String, String, String)] = []
        var closed: [String] = []
        var endsCall = false
    }

    private func model(_ transport: MockLiveVoiceTransport, log: Log, open: (@Sendable (String) async throws -> LiveCall)? = nil) -> LiveVoice {
        LiveVoice(
            open: open ?? { _ in LiveCall(answer: "v=0 answer", id: "rtc_1", seconds: 300) },
            logTurn: { call, question, reply in log.turns.append((call, question, reply)); return log.endsCall },
            close: { log.closed.append($0) },
            makeTransport: { transport },
            micAllowed: { true },
            captionPace: .zero)
    }

    /// Lets the event loop and logging tasks run.
    private func settle() async {
        for _ in 0..<20 { await Task.yield() }
    }

    @Test func aCallThatCantStartFallsBack() async {
        let voice = model(MockLiveVoiceTransport(failing: Down()), log: Log())
        #expect(await voice.begin() == false)
        #expect(voice.phase == .idle)
    }

    @Test func aServerRefusalFallsBackToo() async {
        let voice = model(MockLiveVoiceTransport(), log: Log(), open: { _ in throw Down() })
        #expect(await voice.begin() == false)
        #expect(voice.isActive == false)
    }

    @Test func aLiveCallListensThenLogsEachExchange() async {
        let transport = MockLiveVoiceTransport()
        let log = Log()
        let voice = model(transport, log: log)
        #expect(await voice.begin())
        await settle()
        #expect(voice.phase == .listening)
        #expect(voice.endsAt != nil)

        transport.push(.studentSaid("When did it start?"))
        transport.push(.patientWords("Last "))
        await settle()
        #expect(voice.phase == .patientSpeaking)
        #expect(voice.caption == "Last ")
        transport.push(.patientFinished("Last night."))
        await settle()
        #expect(log.turns.count == 1)
        #expect(log.turns.first?.0 == "rtc_1")
        #expect(log.turns.first?.1 == "When did it start?")
        #expect(voice.phase == .listening)
    }

    @Test func tappingWhileThePatientTalksCutsThemOff() async {
        let transport = MockLiveVoiceTransport()
        let voice = model(transport, log: Log())
        _ = await voice.begin()
        transport.push(.patientWords("Well, "))
        await settle()
        voice.interrupt()
        #expect(transport.cutOffs == 1)
        #expect(voice.phase == .listening)
    }

    @Test func theServerEndingTheCallLeavesAMessage() async {
        let transport = MockLiveVoiceTransport()
        let log = Log()
        log.endsCall = true
        let voice = model(transport, log: log)
        _ = await voice.begin()
        transport.push(.studentSaid("Hi"))
        transport.push(.patientFinished("Hello."))
        await settle()
        guard case .unavailable = voice.phase else { Issue.record("expected the call to end with a message"); return }
        #expect(log.closed == ["rtc_1"])
        #expect(transport.disconnected)
    }

    @Test func endingHangsUpBothSides() async {
        let transport = MockLiveVoiceTransport()
        let log = Log()
        let voice = model(transport, log: log)
        _ = await voice.begin()
        voice.end()
        await settle()
        #expect(log.closed == ["rtc_1"])
        #expect(transport.disconnected)
        #expect(voice.phase == .idle)
    }
}
