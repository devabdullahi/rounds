import Foundation

/// Everything the app asks of the case backend. Models depend on this protocol only; the live
/// version talks to Supabase (`LiveCaseService`).
protocol CaseService: Sendable {
    /// Signs in if needed (anonymously until real accounts are wired up).
    func ensureSignedIn() async throws

    /// The student's ward: generated patients, newest first, with last-attempt status.
    func ward() async throws -> [WardPatient]

    /// Every submitted case the student has been graded on, newest first: what the profile's
    /// points breakdown and badges are built from.
    func gradedCases() async throws -> [GradedCase]
    /// The student's rating, as the server last set it after grading.
    func rating() async throws -> Int

    /// How many conditions each topic can draw from, keyed by `StudyFocus.stored`.
    func topicCounts() async throws -> [String: Int]

    /// Generates a new fictional patient for the focus. `.preparing` means the focus has no
    /// condition ready yet and the server is writing one; ask again shortly.
    func admit(focus: StudyFocus) async throws -> AdmitOutcome

    func loadCase(bed: String) async throws -> ClinicalCase

    /// Deletes the student's own patients and their attempts (all of them when `beds` is nil).
    /// Returns how many were removed. Ratings already earned stay.
    func deletePatients(_ beds: [String]?) async throws -> Int

    func start(bed: String, examMode: Bool, timeLimitMinutes: Int?) async throws -> String
    func ask(attempt: String, question: String) async throws -> PatientAnswer
    func examine(attempt: String, maneuver: String) async throws -> String
    func order(attempt: String, test: String) async throws -> TestResult
    func submit(attempt: String, diagnosis: String, differential: [String], plan: String) async throws -> Grade
}
