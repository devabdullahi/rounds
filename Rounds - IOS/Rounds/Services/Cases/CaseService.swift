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
    /// The student's rating, as the server last set it after grading; nil when the account has no
    /// profile row yet (a guest who hasn't been graded).
    func rating() async throws -> Int?

    /// How many conditions each topic can draw from, keyed by `StudyFocus.stored`.
    func topicCounts() async throws -> [String: Int]

    /// Generates a new fictional patient for the focus. `.preparing` means the server accepted a
    /// background job; set `polling` on follow-up calls while waiting for its ready case.
    func admit(focus: StudyFocus, polling: Bool) async throws -> AdmitOutcome

    /// Asks the server to write the focus's next patient ahead, so the next `admit` is instant.
    /// Returns as soon as the job is queued; nothing is admitted.
    func prepare(focus: StudyFocus) async throws

    func loadCase(bed: String) async throws -> ClinicalCase

    /// The student's graded attempts at one patient, newest first, with tests and exam named.
    func pastTries(bed: String) async throws -> [PastTry]

    /// Deletes the student's own patients and their attempts (all of them when `beds` is nil).
    /// Returns how many were removed. Ratings already earned stay.
    func deletePatients(_ beds: [String]?) async throws -> Int

    func start(bed: String, examMode: Bool, timeLimitMinutes: Int?) async throws -> AttemptStart
    func ask(attempt: String, question: String) async throws -> PatientAnswer
    func examine(attempt: String, maneuver: String) async throws -> String
    func order(attempt: String, test: String) async throws -> TestResult
    /// Voice mode: the student's recorded turn (m4a) as text, transcribed by the server.
    func transcribe(attempt: String, audio: Data) async throws -> String
    /// Voice mode: the patient's latest reply as spoken audio (AAC), in the patient's own voice.
    func speakLatestReply(attempt: String) async throws -> Data
    /// Voice mode: the same reply as raw PCM (24 kHz, 16-bit, mono) in chunks as the server makes
    /// it, so playback starts after the first chunk instead of the whole file.
    func streamLatestReply(attempt: String) async throws -> AsyncThrowingStream<Data, Error>
    /// Voice mode: asks and gets the answer's voice in one round trip (ask, then speak_stream).
    func askAloud(attempt: String, question: String) async throws -> SpokenAnswer
    /// Live voice: hands the phone's WebRTC offer to the server, which opens the call with OpenAI.
    func startLiveCall(attempt: String, offer: String) async throws -> LiveCall
    /// Live voice: logs one finished exchange (the reply was already heard) for the transcript and grade.
    func logVoiceTurn(attempt: String, call: String, question: String, reply: String) async throws -> VoiceTurnOutcome
    /// Live voice: the call ended on the phone; the server hangs up its side too.
    func endLiveCall(attempt: String, call: String) async throws
    func submit(attempt: String, diagnosis: String, differential: [String], plan: String) async throws -> Grade
}
