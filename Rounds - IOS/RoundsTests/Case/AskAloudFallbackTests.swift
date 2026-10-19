import Foundation
import Testing
@testable import Rounds

/// Voice mode against a server that doesn't have ask_aloud yet still gets its answer.
@MainActor
struct AskAloudFallbackTests {
    @Test func anOlderServerAnswersTheSpokenQuestionAsTyped() async throws {
        let session = CaseSession(clinical: ClinicalCase(bed: "X1", name: "Test Patient", age: 40, sex: "F", setting: "", quote: "",
                                                         demeanor: "", complaint: "", vitals: [], task: "", minutes: 10,
                                                         suggestedQuestions: [], exam: [], tests: [], clerkship: nil, system: nil,
                                                         keyHistoryTotal: 0),
                                  service: OlderServer())
        let spoken = try #require(await session.askAloud("When did it start?"))
        #expect(spoken.reply == "Last night.")
        #expect(session.messages.map(\.kind) == [ChatMessage.Kind.doctor, .patient])
    }
}

/// A backend from before ask_aloud: answers ask, refuses the new action as unknown.
private actor OlderServer: CaseService {
    struct Unused: Error {}
    func askAloud(attempt: String, question: String) async throws -> SpokenAnswer { throw CaseServiceError(message: "Unknown action.") }
    func ask(attempt: String, question: String) async throws -> PatientAnswer {
        PatientAnswer(reply: "Last night.", revealed: [], revealedIDs: [], coverage: (0, 0))
    }
    func start(bed: String, examMode: Bool, timeLimitMinutes: Int?) async throws -> AttemptStart { AttemptStart(id: "A1", hiddenTests: []) }
    func examine(attempt: String, maneuver: String) async throws -> String { throw Unused() }
    func rating() async throws -> Int? { nil }
    func ensureSignedIn() async throws {}
    func ward() async throws -> [WardPatient] { [] }
    func topicCounts() async throws -> [String: Int] { [:] }
    func gradedCases() async throws -> [GradedCase] { [] }
    func admit(focus: StudyFocus) async throws -> AdmitOutcome { throw Unused() }
    func loadCase(bed: String) async throws -> ClinicalCase { throw Unused() }
    func pastTries(bed: String) async throws -> [PastTry] { throw Unused() }
    func transcribe(attempt: String, audio: Data) async throws -> String { throw Unused() }
    func speakLatestReply(attempt: String) async throws -> Data { throw Unused() }
    func streamLatestReply(attempt: String) async throws -> AsyncThrowingStream<Data, Error> { throw Unused() }
    func deletePatients(_ beds: [String]?) async throws -> Int { throw Unused() }
    func order(attempt: String, test: String) async throws -> TestResult { throw Unused() }
    func submit(attempt: String, diagnosis: String, differential: [String], plan: String) async throws -> Grade { throw Unused() }
    func startLiveCall(attempt: String, offer: String) async throws -> LiveCall { throw Unused() }
    func logVoiceTurn(attempt: String, call: String, question: String, reply: String) async throws -> VoiceTurnOutcome { throw Unused() }
    func endLiveCall(attempt: String, call: String) async throws { throw Unused() }
}
