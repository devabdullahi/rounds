import Foundation
import Testing
@testable import Rounds

/// A case's first actions can all fire before the server's start returns; they must share one
/// attempt, or the grade misses the work logged on the others.
@MainActor
struct AttemptStartTests {
    @Test func practiceMenuHidesWhatTheServerSays() async {
        let tests = ["chest_x_ray", "hs_tnt"].map {
            Investigation(id: $0, name: $0, detail: "", cost: 10)
        }
        let session = CaseSession(clinical: ClinicalCase(bed: "X1", name: "Test Patient", age: 40, sex: "F", setting: "", quote: "",
                                                         demeanor: "", complaint: "", vitals: [], task: "", minutes: 10,
                                                         suggestedQuestions: [], exam: [], tests: tests, clerkship: nil, system: nil,
                                                         keyHistoryTotal: 0),
                                  service: SlowStartCases())
        #expect(!session.menuReady)
        await session.loadMenu()
        #expect(session.menuReady)
        #expect(session.menu.map(\.id) == ["hs_tnt"])
        #expect(session.testsTaken == (0, 1))
    }

    @Test func quickActionsShareOneAttempt() async throws {
        let service = SlowStartCases()
        let session = CaseSession(clinical: ClinicalCase(bed: "X1", name: "Test Patient", age: 40, sex: "F", setting: "", quote: "",
                                                         demeanor: "", complaint: "", vitals: [], task: "", minutes: 10,
                                                         suggestedQuestions: [], exam: [], tests: [], clerkship: nil, system: nil,
                                                         keyHistoryTotal: 0),
                                  service: service)

        session.examine("abdomen")
        session.examine("chest")
        try await Task.sleep(for: .milliseconds(400))

        #expect(await service.starts == 1)
        #expect(await service.examinedOn == ["A1", "A1"])
    }

    /// A case the student left comes back as they left it, and new work goes on the same attempt.
    @Test func aLeftCaseContinuesOnItsAttempt() async throws {
        let tests = [Investigation(id: "cbc", name: "CBC", detail: "", cost: 10)]
        let service = SlowStartCases()
        let session = CaseSession(clinical: ClinicalCase(bed: "X1", name: "Test Patient", age: 40, sex: "F", setting: "", quote: "",
                                                         demeanor: "", complaint: "", vitals: [], task: "", minutes: 10,
                                                         suggestedQuestions: [], exam: [], tests: tests, clerkship: nil, system: nil,
                                                         keyHistoryTotal: 4),
                                  service: service)
        let started = Date(timeIntervalSinceNow: -300)
        session.restore(ResumedAttempt(
            id: "LEFT", examMode: false, timeLimitMinutes: 15, startedAt: started,
            transcript: [.init(fromStudent: true, text: "When did it start?"), .init(fromStudent: false, text: "Last night.")],
            revealedIDs: ["f1"], coverage: (1, 4), examined: [("abdomen", "Soft, non-tender.")],
            ordered: [.init(id: "cbc", at: started, result: TestResult(text: "WBC 14", isAbnormal: true))], hiddenTests: []))

        #expect(session.resumed)
        #expect(session.messages.map(\.text) == ["When did it start?", "Last night."])
        #expect(session.historyCoverage == (1, 4))
        #expect(session.findings["abdomen"] == "Soft, non-tender.")
        #expect(session.tests["cbc"] == .ready)
        #expect(session.testsTaken == (1, 1))
        #expect(session.startedAt == started)

        session.examine("chest")
        try await Task.sleep(for: .milliseconds(100))
        #expect(await service.starts == 0)
        #expect(await service.examinedOn == ["LEFT"])
    }
}

/// Starts slowly, so two actions overlap the first start.
private actor SlowStartCases: CaseService {
    private(set) var starts = 0
    private(set) var examinedOn: [String] = []
    struct Unused: Error {}

    func start(bed: String, examMode: Bool, timeLimitMinutes: Int?) async throws -> AttemptStart {
        starts += 1
        try await Task.sleep(for: .milliseconds(100))
        return AttemptStart(id: "A\(starts)", hiddenTests: ["chest_x_ray"])
    }

    func resume(bed: String) async throws -> ResumedAttempt? { nil }

    func examine(attempt: String, maneuver: String) async throws -> String {
        examinedOn.append(attempt)
        return "normal"
    }

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
    func askAloud(attempt: String, question: String) async throws -> SpokenAnswer { throw Unused() }
    func deletePatients(_ beds: [String]?) async throws -> Int { throw Unused() }
    func ask(attempt: String, question: String) async throws -> PatientAnswer { throw Unused() }
    func order(attempt: String, test: String) async throws -> TestResult { throw Unused() }
    func submit(attempt: String, diagnosis: String, differential: [String], plan: String) async throws -> Grade { throw Unused() }
    func startLiveCall(attempt: String, offer: String) async throws -> LiveCall { throw Unused() }
    func logVoiceTurn(attempt: String, call: String, question: String, reply: String) async throws -> VoiceTurnOutcome { throw Unused() }
    func endLiveCall(attempt: String, call: String) async throws { throw Unused() }
}
