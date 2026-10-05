import Foundation

/// Everything the app asks of the case backend. Models depend on this protocol only; the live
/// version talks to Supabase (`LiveCaseService`).
protocol CaseService: Sendable {
    /// Signs in if needed (anonymously until real accounts are wired up).
    func ensureSignedIn() async throws

    /// The student's ward: generated patients, newest first, with last-attempt status.
    func ward() async throws -> [WardPatient]

    /// How many conditions each topic can draw from, keyed by `StudyFocus.stored`.
    func topicCounts() async throws -> [String: Int]

    /// Generates a new fictional patient for the focus and returns its bed code.
    func admit(focus: StudyFocus) async throws -> String

    func loadCase(bed: String) async throws -> ClinicalCase

    func start(bed: String, examMode: Bool, timeLimitMinutes: Int?) async throws -> String
    func ask(attempt: String, question: String) async throws -> PatientAnswer
    func examine(attempt: String, maneuver: String) async throws -> String
    func order(attempt: String, test: String) async throws -> TestResult
    func submit(attempt: String, diagnosis: String, differential: [String], plan: String) async throws -> Grade
}

/// The patient's reply to one question.
struct PatientAnswer: Sendable {
    let reply: String
    /// Newly revealed topics (empty in exam mode, where labels stay hidden).
    let revealed: [(id: String, label: String)]
    /// Every fact id revealed so far, so suggestions can hide what's been covered.
    let revealedIDs: [String]
    let coverage: (got: Int, total: Int)
}

/// A backend failure, phrased for the student.
struct CaseServiceError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}
