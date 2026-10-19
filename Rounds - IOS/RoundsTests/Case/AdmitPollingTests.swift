import Foundation
import Testing
@testable import Rounds

/// Admitting when the focus's first condition is still being written: the app asks again until a
/// patient is ready.
@MainActor
struct AdmitPollingTests {
    @Test func asksAgainWhilePreparingThenOpensThePatient() async {
        let service = ScriptedCases(replies: [.preparing, .preparing, .admitted(bed: "A12")])
        let app = AppState(cases: service, cards: nil)
        app.preparingPoll = .milliseconds(1)

        await app.admit(focus: FocusSelection())

        #expect(await service.admitCalls == 3)
        #expect(await service.loadedBeds == ["A12"])
        #expect(!app.isAdmitting)
        #expect(!app.isPreparingCondition)
    }

    @Test func aReadyPatientIsOpenedWithoutWaiting() async {
        let service = ScriptedCases(replies: [.admitted(bed: "B7")])
        let app = AppState(cases: service, cards: nil)

        await app.admit(focus: FocusSelection())

        #expect(await service.admitCalls == 1)
        #expect(await service.loadedBeds == ["B7"])
    }

    @Test func queuingAdmitsWithoutOpeningTheCase() async {
        let service = ScriptedCases(replies: [.admitted(bed: "C3")])
        let app = AppState(cases: service, cards: nil)

        let outcome = await app.queuePatient(focus: FocusSelection())

        #expect(outcome == .ready(nil))
        #expect(await service.loadedBeds.isEmpty)
        #expect(app.activeCase == nil)
    }

    @Test func queuingAsksOnceWhilePreparing() async {
        let service = ScriptedCases(replies: [.preparing, .admitted(bed: "D4")])
        let app = AppState(cases: service, cards: nil)

        #expect(await app.queuePatient(focus: FocusSelection()) == .preparing)
        #expect(await service.admitCalls == 1)
    }
}

/// A case service that answers `admit` from a script and records which beds were opened.
private actor ScriptedCases: CaseService {
    func rating() async throws -> Int? { nil }
    private var replies: [AdmitOutcome]
    private(set) var admitCalls = 0
    private(set) var loadedBeds: [String] = []

    init(replies: [AdmitOutcome]) { self.replies = replies }

    struct Unused: Error {}

    func ensureSignedIn() async throws {}
    func ward() async throws -> [WardPatient] { [] }
    func topicCounts() async throws -> [String: Int] { [:] }
    func gradedCases() async throws -> [GradedCase] { [] }

    func admit(focus: StudyFocus) async throws -> AdmitOutcome {
        admitCalls += 1
        return replies.isEmpty ? .preparing : replies.removeFirst()
    }

    func loadCase(bed: String) async throws -> ClinicalCase {
        loadedBeds.append(bed)
        throw Unused() // opening the case isn't under test
    }

    func pastTries(bed: String) async throws -> [PastTry] { throw Unused() }
    func transcribe(attempt: String, audio: Data) async throws -> String { throw Unused() }
    func speakLatestReply(attempt: String) async throws -> Data { throw Unused() }
    func streamLatestReply(attempt: String) async throws -> AsyncThrowingStream<Data, Error> { throw Unused() }
    func deletePatients(_ beds: [String]?) async throws -> Int { throw Unused() }
    func start(bed: String, examMode: Bool, timeLimitMinutes: Int?) async throws -> AttemptStart { throw Unused() }
    func ask(attempt: String, question: String) async throws -> PatientAnswer { throw Unused() }
    func examine(attempt: String, maneuver: String) async throws -> String { throw Unused() }
    func order(attempt: String, test: String) async throws -> TestResult { throw Unused() }
    func submit(attempt: String, diagnosis: String, differential: [String], plan: String) async throws -> Grade { throw Unused() }
}
