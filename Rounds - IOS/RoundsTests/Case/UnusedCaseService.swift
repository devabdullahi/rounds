import Foundation
@testable import Rounds

/// A case service for tests that build a `CaseSession` but never reach the server: every call throws.
actor UnusedCaseService: CaseService {
    struct Unused: Error {}

    func start(bed: String, examMode: Bool, timeLimitMinutes: Int?) async throws -> AttemptStart { throw Unused() }
    func resume(bed: String) async throws -> ResumedAttempt? { throw Unused() }
    func examine(attempt: String, maneuver: String) async throws -> String { throw Unused() }
    func rating() async throws -> Int? { throw Unused() }
    func ensureSignedIn() async throws { throw Unused() }
    func ward() async throws -> [WardPatient] { throw Unused() }
    func topicCounts() async throws -> [String: Int] { throw Unused() }
    func gradedCases() async throws -> [GradedCase] { throw Unused() }
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
    func submit(attempt: String, diagnosis: String, differential: [String], plan: String, focus: GradingFocus) async throws -> Grade { throw Unused() }
    func startLiveCall(attempt: String, offer: String) async throws -> LiveCall { throw Unused() }
    func logVoiceTurn(attempt: String, call: String, question: String, reply: String) async throws -> VoiceTurnOutcome { throw Unused() }
    func endLiveCall(attempt: String, call: String) async throws { throw Unused() }
}
