import Foundation
import Testing
@testable import Rounds

/// A streamed answer shows in one bubble that grows, then settles on the finished reply.
@MainActor
struct StreamedAnswerTests {
    private func session(_ steps: [AnswerProgress], failing: Bool = false) -> CaseSession {
        CaseSession(clinical: ClinicalCase(bed: "X1", name: "Test Patient", age: 40, sex: "F", setting: "", quote: "",
                                           demeanor: "", complaint: "", vitals: [], task: "", minutes: 10,
                                           suggestedQuestions: [], exam: [], tests: [], clerkship: nil, system: nil,
                                           keyHistoryTotal: 0),
                    service: StreamingServer(steps: steps, failing: failing))
    }

    /// Waits until the answer has finished (the session stops waiting on the patient).
    private func finished(_ session: CaseSession) async throws {
        for _ in 0..<200 where session.isPatientTyping { try await Task.sleep(for: .milliseconds(5)) }
        #expect(!session.isPatientTyping)
    }

    @Test func aStreamedReplyGrowsInOneBubbleThenSettles() async throws {
        let answer = PatientAnswer(reply: "Last night, around midnight.", revealed: [("a1", "Onset")], revealedIDs: ["a1"], coverage: (1, 4))
        let session = session([.writing("Last"), .writing("Last night,"), .done(answer)])
        session.ask("When did it start?")
        try await finished(session)
        #expect(session.messages.map(\.kind) == [.doctor, .patient, .reveal])
        #expect(session.messages[1].text == "Last night, around midnight.")
        #expect(session.writingID == nil)
        #expect(!session.showsTypingDots)
        #expect(session.coverage == (1, 4))
    }

    @Test func theFinishedReplyReplacesWhatWasShown() async throws {
        // The server swapped a reply that failed its checks after some of it showed.
        let answer = PatientAnswer(reply: "Not that I've noticed, no.", revealed: [], revealedIDs: [], coverage: (0, 4))
        let session = session([.writing("Well, my doctor"), .done(answer)])
        session.ask("Any diagnosis before?")
        try await finished(session)
        #expect(session.messages.filter { $0.kind == .patient }.map(\.text) == ["Not that I've noticed, no."])
    }

    @Test func aReplyCutOffMidwayLeavesOnlyTheProblem() async throws {
        let session = session([.writing("It started")], failing: true)
        session.ask("When did it start?")
        try await finished(session)
        #expect(session.messages.map(\.kind) == [.doctor, .problem])
    }
}

/// A backend that streams a scripted answer, or fails after it.
private actor StreamingServer: CaseService {
    struct Unused: Error {}
    struct Dropped: Error {}
    let steps: [AnswerProgress]
    let failing: Bool

    init(steps: [AnswerProgress], failing: Bool) {
        self.steps = steps
        self.failing = failing
    }

    func askStreaming(attempt: String, question: String) async throws -> AsyncThrowingStream<AnswerProgress, Error> {
        let (steps, failing) = (steps, failing)
        return AsyncThrowingStream { continuation in
            for step in steps { continuation.yield(step) }
            continuation.finish(throwing: failing ? Dropped() : nil)
        }
    }
    func ask(attempt: String, question: String) async throws -> PatientAnswer { throw Unused() }
    func askAloud(attempt: String, question: String) async throws -> SpokenAnswer { throw Unused() }
    func start(bed: String, examMode: Bool, timeLimitMinutes: Int?) async throws -> AttemptStart { AttemptStart(id: "A1", hiddenTests: []) }
    func resume(bed: String) async throws -> ResumedAttempt? { nil }
    func examine(attempt: String, maneuver: String) async throws -> String { throw Unused() }
    func rating() async throws -> Int? { nil }
    func ensureSignedIn() async throws {}
    func ward() async throws -> [WardPatient] { [] }
    func topicCounts() async throws -> [String: Int] { [:] }
    func gradedCases() async throws -> [GradedCase] { [] }
    func admit(focus: StudyFocus, setting: CareSetting, polling: Bool) async throws -> AdmitOutcome { throw Unused() }
    func prepare(focus: StudyFocus, setting: CareSetting) async throws { throw Unused() }
    func loadCase(bed: String) async throws -> ClinicalCase { throw Unused() }
    func pastTries(bed: String) async throws -> [PastTry] { throw Unused() }
    func transcribe(attempt: String, audio: Data) async throws -> String { throw Unused() }
    func speakLatestReply(attempt: String) async throws -> Data { throw Unused() }
    func streamLatestReply(attempt: String) async throws -> AsyncThrowingStream<Data, Error> { throw Unused() }
    func deletePatients(_ beds: [String]?) async throws -> Int { throw Unused() }
    func order(attempt: String, test: String) async throws -> TestResult { throw Unused() }
    func submit(attempt: String, diagnosis: String, differential: [String], plan: String, focus: GradingFocus) async throws -> Grade { throw Unused() }
    func startLiveCall(attempt: String, offer: String) async throws -> LiveCall { throw Unused() }
    func logVoiceTurn(attempt: String, call: String, question: String, reply: String) async throws -> VoiceTurnOutcome { throw Unused() }
    func endLiveCall(attempt: String, call: String) async throws { throw Unused() }
}
