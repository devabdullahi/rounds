import Foundation
import Testing
@testable import Rounds

/// A case's first actions can all fire before the server's start returns; they must share one
/// attempt, or the grade misses the work logged on the others.
@MainActor
struct AttemptStartTests {
    @Test func quickActionsShareOneAttempt() async throws {
        let service = SlowStartCases()
        let session = CaseSession(clinical: ClinicalCase(bed: "X1", name: "Test Patient", age: 40, sex: "F", setting: "", quote: "",
                                                         demeanor: "", complaint: "", vitals: [], task: "", minutes: 10, budget: 1000,
                                                         suggestedQuestions: [], exam: [], tests: [], clerkship: nil, system: nil,
                                                         keyHistoryTotal: 0),
                                  service: service)

        session.examine("abdomen")
        session.examine("chest")
        try await Task.sleep(for: .milliseconds(400))

        #expect(await service.starts == 1)
        #expect(await service.examinedOn == ["A1", "A1"])
    }
}

/// Starts slowly, so two actions overlap the first start.
private actor SlowStartCases: CaseService {
    private(set) var starts = 0
    private(set) var examinedOn: [String] = []
    struct Unused: Error {}

    func start(bed: String, examMode: Bool, timeLimitMinutes: Int?) async throws -> String {
        starts += 1
        try await Task.sleep(for: .milliseconds(100))
        return "A\(starts)"
    }

    func examine(attempt: String, maneuver: String) async throws -> String {
        examinedOn.append(attempt)
        return "normal"
    }

    func rating() async throws -> Int? { nil }
    func ensureSignedIn() async throws {}
    func ward() async throws -> [WardPatient] { [] }
    func topicCounts() async throws -> [String: Int] { [:] }
    func gradedCases() async throws -> [GradedCase] { [] }
    func admit(focus: StudyFocus) async throws -> AdmitOutcome { throw Unused() }
    func loadCase(bed: String) async throws -> ClinicalCase { throw Unused() }
    func deletePatients(_ beds: [String]?) async throws -> Int { throw Unused() }
    func ask(attempt: String, question: String) async throws -> PatientAnswer { throw Unused() }
    func order(attempt: String, test: String) async throws -> TestResult { throw Unused() }
    func submit(attempt: String, diagnosis: String, differential: [String], plan: String) async throws -> Grade { throw Unused() }
}
