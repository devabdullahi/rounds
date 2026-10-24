import Foundation
import Supabase

/// `CaseService` over Supabase: table reads for the door note and ward, edge functions
/// (`generate-case`, `case-session`) for everything privileged.
struct LiveCaseService: CaseService {
    let client: SupabaseClient

    func ensureSignedIn() async throws {
        do {
            _ = try await client.auth.session
        } catch AuthError.sessionMissing {
            // Every student has a registered account; there are no guest sessions to fall back to.
            throw AuthServiceError(message: "Sign in to see your patients.")
        }
    }

    // MARK: Ward

    func ward() async throws -> [WardPatient] {
        let user = try await client.auth.session.user.id
        let cases: [CaseRow] = try await client.from("cases")
            .select("id, patient_name, age, sex, quote, vitals, clerkship, organ_system, created_at")
            .eq("created_by", value: user)
            .order("created_at", ascending: false)
            .execute().value
        let attempts: [AttemptRow] = try await client.from("attempts")
            .select("case_id, submitted_at, score, grade, started_at")
            .order("started_at", ascending: false)
            .execute().value
        return cases.map { c in
            let mine = attempts.filter { $0.case_id == c.id }
            return c.wardPatient(latest: mine.first, tries: mine.filter { $0.submitted_at != nil }.count)
        }
    }

    func gradedCases() async throws -> [GradedCase] {
        // RLS returns only the caller's attempts; the case supplies its rotation and system.
        let rows: [GradedAttemptRow] = try await client.from("attempts")
            .select("id, case_id, submitted_at, score, grade, exam_mode, time_limit_minutes, cases(clerkship, organ_system)")
            .not("submitted_at", operator: .is, value: "null")
            .order("submitted_at", ascending: false)
            .execute().value
        return rows.compactMap(\.gradedCase)
    }

    func rating() async throws -> Int? {
        let user = try await client.auth.session.user.id
        let rows: [RatingRow] = try await client.from("profiles").select("rating").eq("id", value: user)
            .limit(1).execute().value
        return rows.first?.rating
    }

    func topicCounts() async throws -> [String: Int] {
        let rows: [TopicCountRow] = try await client.rpc("topic_counts").execute().value
        return Dictionary(rows.map { ("\($0.kind):\($0.topic)", $0.conditions) }, uniquingKeysWith: +)
    }

    func admit(focus: StudyFocus, setting: CareSetting, polling: Bool) async throws -> AdmitOutcome {
        let reply: AdmitReply = try await invoke("generate-case", AdmitBody(focus: focus.stored, setting: setting.rawValue, polling: polling))
        if let bed = reply.case_id { return .admitted(bed: bed) }
        guard reply.status == "preparing" else { throw CaseServiceError(message: "The server sent no patient.") }
        return .preparing
    }

    func prepare(focus: StudyFocus, setting: CareSetting) async throws {
        let _: AdmitReply = try await invoke("generate-case", PrepareBody(focus: focus.stored, setting: setting.rawValue))
    }

    func deletePatients(_ beds: [String]?) async throws -> Int {
        // The database function checks ownership; a bed that isn't the caller's is skipped.
        try await client.rpc("delete_patients", params: DeleteBody(case_ids: beds)).execute().value
    }

    func loadCase(bed: String) async throws -> ClinicalCase {
        let row: CaseDetailRow = try await client.from("cases")
            .select("id, patient_name, age, sex, quote, complaint, setting, demeanor, task, vitals, minutes, suggested, maneuvers, test_menu, clerkship, organ_system, key_history")
            .eq("id", value: bed)
            .single()
            .execute().value
        return row.clinicalCase
    }

    func pastTries(bed: String) async throws -> [PastTry] {
        // RLS returns only the caller's attempts. The case's menu turns logged ids into names.
        async let rows: [PastTryRow] = client.from("attempts")
            .select("id, submitted_at, score, grade, diagnosis, differential, plan, ordered_tests, examined, exam_mode")
            .eq("case_id", value: bed)
            .not("submitted_at", operator: .is, value: "null")
            .order("submitted_at", ascending: false)
            .execute().value
        let clinical = try await loadCase(bed: bed)
        return try await rows.compactMap { $0.pastTry(tests: clinical.tests, exam: clinical.exam) }
    }

    /// Maps stored attempt rows to `PastTry`s. Exposed so tests can check the wire mapping without a network call.
    static func decodePastTries(from data: Data, tests: [Investigation], exam: [ExamManeuver]) throws -> [PastTry] {
        try JSONDecoder().decode([PastTryRow].self, from: data).compactMap { $0.pastTry(tests: tests, exam: exam) }
    }

    // MARK: Encounter

    func start(bed: String, examMode: Bool, timeLimitMinutes: Int?) async throws -> AttemptStart {
        let reply: StartReply = try await invoke("case-session", StartBody(case_id: bed, exam_mode: examMode, time_limit_minutes: timeLimitMinutes))
        return AttemptStart(id: reply.attempt_id, hiddenTests: Set(reply.hidden_tests ?? []))
    }

    func resume(bed: String) async throws -> ResumedAttempt? {
        let reply: ResumeReply = try await invoke("case-session", ["action": "resume", "case_id": bed])
        return reply.attempt?.resumed
    }

    func ask(attempt: String, question: String) async throws -> PatientAnswer {
        let r: AskReply = try await invoke("case-session", ["action": "ask", "attempt_id": attempt, "question": question])
        return r.answer
    }

    func askStreaming(attempt: String, question: String) async throws -> AsyncThrowingStream<AnswerProgress, Error> {
        let bytes: URLSession.AsyncBytes
        do {
            bytes = try await stream(["action": "ask_stream", "attempt_id": attempt, "question": question])
        } catch let error as CaseServiceError where error.message == "Unknown action." {
            // A server from before ask_stream: the whole answer at once.
            let answer = try await ask(attempt: attempt, question: question)
            return AsyncThrowingStream { $0.yield(.done(answer)); $0.finish() }
        }
        return AsyncThrowingStream { continuation in
            let reading = Task {
                do {
                    // One JSON object per line: the reply so far, then the answer (or an error).
                    for try await line in bytes.lines {
                        let data = Data(line.utf8)
                        let step = try JSONDecoder().decode(AskStreamLine.self, from: data)
                        switch step.type {
                        case "text":
                            if let text = step.text { continuation.yield(.writing(text)) }
                        case "done":
                            continuation.yield(.done(try JSONDecoder().decode(AskReply.self, from: data).answer))
                            continuation.finish()
                            return
                        case "error":
                            throw CaseServiceError(message: Self.sentence(step.error ?? "the patient didn't answer; try again"))
                        default:
                            continue   // a step this build doesn't know
                        }
                    }
                    throw CaseServiceError(message: "The patient didn't answer; try again.")
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in reading.cancel() }
        }
    }

    func examine(attempt: String, maneuver: String) async throws -> String {
        let r: ExamineReply = try await invoke("case-session", ["action": "examine", "attempt_id": attempt, "maneuver_id": maneuver])
        return r.finding
    }

    func order(attempt: String, test: String) async throws -> TestResult {
        let r: OrderReply = try await invoke("case-session", ["action": "order", "attempt_id": attempt, "test_id": test])
        return TestResult(text: r.result, isAbnormal: r.abnormal)
    }

    func transcribe(attempt: String, audio: Data) async throws -> String {
        let r: TranscribeReply = try await invoke("case-session", TranscribeBody(attempt_id: attempt, audio: audio.base64EncodedString()))
        return r.text
    }

    func speakLatestReply(attempt: String) async throws -> Data {
        let r: SpeakReply = try await invoke("case-session", ["action": "speak", "attempt_id": attempt])
        guard let audio = Data(base64Encoded: r.audio) else { throw CaseServiceError(message: "The server sent unreadable audio.") }
        return audio
    }

    func startLiveCall(attempt: String, offer: String) async throws -> LiveCall {
        let r: LiveCallReply = try await invoke("case-session", ["action": "voice_session", "attempt_id": attempt, "sdp": offer])
        return LiveCall(answer: r.sdp, id: r.call_id, idleSeconds: r.idle_seconds ?? r.seconds ?? LiveCall.defaultIdleSeconds)
    }

    func logVoiceTurn(attempt: String, call: String, question: String, reply: String) async throws -> VoiceTurnOutcome {
        let r: VoiceTurnReply = try await invoke("case-session", [
            "action": "voice_turn", "attempt_id": attempt, "call_id": call, "question": question, "reply": reply,
        ])
        let answer = PatientAnswer(reply: r.reply, revealed: r.revealed.map { ($0.id, $0.label) }, revealedIDs: r.revealed_ids,
                                   coverage: (r.coverage.got, r.coverage.total))
        return VoiceTurnOutcome(answer: answer, brokeRule: r.flag != nil, ended: r.ended)
    }

    func endLiveCall(attempt: String, call: String) async throws {
        let _: EmptyReply = try await invoke("case-session", ["action": "voice_end", "attempt_id": attempt, "call_id": call])
    }

    func streamLatestReply(attempt: String) async throws -> AsyncThrowingStream<Data, Error> {
        let bytes = try await stream(["action": "speak_stream", "attempt_id": attempt])
        return Self.audioChunks(bytes.makeAsyncIterator())
    }

    func askAloud(attempt: String, question: String) async throws -> SpokenAnswer {
        let bytes = try await stream(["action": "ask_aloud", "attempt_id": attempt, "question": question])
        // The first line is the answer as JSON; everything after it is the reply's voice.
        var iterator = bytes.makeAsyncIterator()
        var line = Data()
        while let byte = try await iterator.next(), byte != UInt8(ascii: "\n") { line.append(byte) }
        let answer = try JSONDecoder().decode(AskReply.self, from: line).answer
        return SpokenAnswer(answer: answer, audio: Self.audioChunks(iterator))
    }

    /// A case-session call whose reply streams, with the server's error text on a refusal.
    private func stream(_ body: [String: String]) async throws -> URLSession.AsyncBytes {
        guard let project = SupabaseService.project else { throw CaseServiceError(message: "Supabase isn't configured.") }
        do {
            return try await client.streamSigned("case-session", body: body, project: project)
        } catch let FunctionsError.httpError(code, data) {
            let message = (try? JSONDecoder().decode(ErrorReply.self, from: data))?.error
            throw CaseServiceError(message: message.map(Self.sentence) ?? "The server returned \(code).")
        }
    }

    /// The server's lower-case error text as a sentence for the chat.
    private static func sentence(_ message: String) -> String {
        "\(message.prefix(1).uppercased())\(message.dropFirst())."
    }

    /// The rest of a response as PCM chunks of about 100 ms each.
    private static func audioChunks(_ source: URLSession.AsyncBytes.AsyncIterator) -> AsyncThrowingStream<Data, Error> {
        AsyncThrowingStream { continuation in
            let reading = Task {
                var bytes = source
                // ~100 ms of audio per chunk: small enough to start fast, large enough to schedule cheaply.
                let chunkBytes = 4_800
                var chunk = Data(capacity: chunkBytes)
                do {
                    while let byte = try await bytes.next() {
                        chunk.append(byte)
                        if chunk.count >= chunkBytes { continuation.yield(chunk); chunk.removeAll(keepingCapacity: true) }
                    }
                    if !chunk.isEmpty { continuation.yield(chunk) }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in reading.cancel() }
        }
    }

    func submit(attempt: String, diagnosis: String, differential: [String], plan: String, focus: GradingFocus) async throws -> Grade {
        let r: GradeRow = try await invoke("case-session", SubmitBody(attempt_id: attempt, diagnosis: diagnosis, differential: differential, plan: plan,
                                                                               goal: focus.goal?.rawValue, struggles: focus.struggleValues))
        return r.grade
    }

    /// Maps the server's grade JSON to a `Grade`. Exposed so tests can check the wire mapping
    /// (including older grades without the teaching fields) without a network call.
    static func decodeGrade(from data: Data) throws -> Grade {
        try JSONDecoder().decode(GradeRow.self, from: data).grade
    }

    // MARK: Plumbing

    private func invoke<Body: Encodable, Reply: Decodable>(_ function: String, _ body: Body) async throws -> Reply {
        do {
            return try await client.invokeSigned(function, body: body)
        } catch let FunctionsError.httpError(code, data) {
            let message = (try? JSONDecoder().decode(ErrorReply.self, from: data))?.error
            throw CaseServiceError(message: message.map { "\($0.prefix(1).uppercased())\($0.dropFirst())." } ?? "The server returned \(code).")
        }
    }
}

// MARK: - Wire types (snake_case, as the backend sends them)

private struct VitalRow: Decodable { let id: String; let label: String; let value: String; let abnormal: Bool }

private struct CaseRow: Decodable {
    let id: String
    let patient_name: String
    let age: Int
    let sex: String
    let quote: String
    let vitals: [VitalRow]
    let clerkship: String?
    let organ_system: String?

    func wardPatient(latest: AttemptRow?, tries: Int) -> WardPatient {
        let rotation = clerkship.flatMap(Clerkship.init(rawValue:))
        let status: WardPatient.Status
        let misses = latest?.grade?.missed_red_flags.map { Miss(flag: $0.flag, why: $0.why) } ?? []
        let missedDiagnosis = latest?.grade?.diagnosis_correct == false ? latest?.grade?.diagnosis : nil
        switch latest {
        case nil: status = .new
        case let a? where a.submitted_at == nil: status = .resume
        default: status = misses.isEmpty && missedDiagnosis == nil ? .done : .revisit
        }
        let vital = { (id: String) in vitals.first { $0.id == id }?.value }
        return WardPatient(
            id: id, quote: quote,
            meta: [sex, PatientAge.label(age), rotation?.label].compactMap { $0 }.joined(separator: " · "),
            rotation: rotation, system: organ_system.flatMap(OrganSystem.init(rawValue:)),
            hr: vital("hr").flatMap { Int($0) }, bp: vital("sbp"),
            spo2: vital("spo2").flatMap { Int($0.trimmingCharacters(in: CharacterSet(charactersIn: "%"))) },
            status: status, misses: misses, missedDiagnosis: missedDiagnosis, lastScore: latest?.score, tries: tries)
    }
}

private struct CaseDetailRow: Decodable {
    struct Suggested: Decodable { let text: String; let fact: String }
    struct Maneuver: Decodable { let id: String; let title: String }
    struct MenuTest: Decodable { let id: String; let name: String; let detail: String; let cost: Int; let turnaround_s: Double; let delays_care_min: Int? }

    let id: String
    let patient_name: String
    let age: Int
    let sex: String
    let quote: String
    let complaint: String
    let setting: String
    let demeanor: String
    let task: String
    let vitals: [VitalRow]
    let minutes: Int
    let suggested: [Suggested]
    let maneuvers: [Maneuver]
    let test_menu: [MenuTest]
    let clerkship: String?
    let organ_system: String?
    let key_history: Int

    var clinicalCase: ClinicalCase {
        ClinicalCase(
            bed: id, name: patient_name, age: age, sex: sex, setting: setting, quote: quote, demeanor: demeanor,
            complaint: complaint,
            vitals: vitals.map { Vital(id: $0.id, label: $0.label, value: $0.value, isAbnormal: $0.abnormal) },
            task: task, minutes: minutes,
            suggestedQuestions: suggested.map { SuggestedQuestion(text: $0.text, fact: $0.fact) },
            exam: maneuvers.map { ExamManeuver(id: $0.id, title: $0.title) },
            tests: test_menu.map { Investigation(id: $0.id, name: $0.name, detail: $0.detail, cost: $0.cost,
                                                 delaysCareMinutes: $0.delays_care_min ?? 0) },
            clerkship: clerkship.flatMap(Clerkship.init(rawValue:)), system: organ_system.flatMap(OrganSystem.init(rawValue:)),
            keyHistoryTotal: key_history)
    }
}

private struct AttemptRow: Decodable {
    struct GradeSummary: Decodable {
        let missed_red_flags: [MissRow]
        let diagnosis_correct: Bool?
        let diagnosis: String?
    }
    let case_id: String
    let submitted_at: String?
    let score: Int?
    let grade: GradeSummary?
}

private struct MissRow: Decodable { let flag: String; let why: String }

/// A submitted attempt with what the student answered and did. The stored grade has no `rating`
/// (that's returned only at submit), so it's read here rather than through `GradeRow`.
private struct PastTryRow: Decodable {
    struct Ordered: Decodable { let id: String }
    struct GradeBody: Decodable {
        let verdict: String
        let diagnosis_correct: Bool
        let diagnosis: String
        let feedback: [GradeRow.FeedbackRow]
        let missed_red_flags: [MissRow]
    }
    let id: String
    let submitted_at: String
    let score: Int?
    let grade: GradeBody?
    let diagnosis: String?
    let differential: [String]?
    let plan: String?
    let ordered_tests: [Ordered]?
    let examined: [String]?
    let exam_mode: Bool?

    /// Nil for an attempt without a stored grade. Ids no longer on the case's menu are left out.
    func pastTry(tests: [Investigation], exam: [ExamManeuver]) -> PastTry? {
        guard let grade, let score, let date = GradedAttemptRow.timestamp(submitted_at) else { return nil }
        return PastTry(
            id: id, submittedAt: date, score: score, verdict: grade.verdict, diagnosisCorrect: grade.diagnosis_correct,
            actualDiagnosis: grade.diagnosis, yourDiagnosis: diagnosis ?? "", differential: differential ?? [], plan: plan ?? "",
            testsOrdered: (ordered_tests ?? []).compactMap { o in tests.first { $0.id == o.id }?.name },
            examDone: (examined ?? []).compactMap { id in exam.first { $0.id == id }?.title },
            feedback: grade.feedback.map { Feedback(tone: $0.tone == "good" ? .good : .miss, title: $0.title, detail: $0.detail, coversMiss: $0.covers_miss, isFocus: $0.focus ?? false) },
            missedRedFlags: grade.missed_red_flags.map { Miss(flag: $0.flag, why: $0.why) },
            examMode: exam_mode ?? false)
    }
}

private struct GradedAttemptRow: Decodable {
    struct GradeBody: Decodable {
        struct Part: Decodable { let got: Int; let max: Int }
        let diagnosis_correct: Bool
        let missed_red_flags: [MissRow]
        /// Absent on cases graded before the server recorded it.
        let breakdown: [String: Part]?
    }
    struct CaseTags: Decodable { let clerkship: String?; let organ_system: String? }

    let id: String
    let case_id: String?
    let submitted_at: String
    let score: Int?
    let grade: GradeBody?
    let exam_mode: Bool?
    let time_limit_minutes: Int?
    let cases: CaseTags?

    var gradedCase: GradedCase? {
        guard let grade, let score, let date = Self.timestamp(submitted_at) else { return nil }
        var breakdown: [ScoreCategory: Points] = [:]
        for (key, part) in grade.breakdown ?? [:] {
            if let category = ScoreCategory(rawValue: key) { breakdown[category] = Points(got: part.got, max: part.max) }
        }
        return GradedCase(id: id, submittedAt: date, score: score, diagnosisCorrect: grade.diagnosis_correct,
                          missedRedFlags: grade.missed_red_flags.count,
                          clerkship: cases?.clerkship.flatMap(Clerkship.init(rawValue:)),
                          system: cases?.organ_system.flatMap(OrganSystem.init(rawValue:)),
                          breakdown: breakdown, examMode: exam_mode ?? false, timed: time_limit_minutes != nil,
                          caseID: case_id)
    }

    /// Postgres timestamptz ("2026-10-05T23:12:01.123456+00:00"). Microseconds trip the ISO
    /// parser, so the fraction is dropped; seconds are plenty for "last 7 days".
    static func timestamp(_ text: String) -> Date? {
        let trimmed = text.replacingOccurrences(of: #"\.\d+"#, with: "", options: .regularExpression)
        return ISO8601DateFormatter().date(from: trimmed)
    }
}
private struct RatingRow: Decodable { let rating: Int }
private struct TopicCountRow: Decodable { let kind: String; let topic: String; let conditions: Int }
private struct ErrorReply: Decodable { let error: String }
private struct DeleteBody: Encodable { let case_ids: [String]? }
/// `{case_id}` once written, or `{status: "preparing"}` (HTTP 202) while the focus's first condition is.
private struct AdmitReply: Decodable { let case_id: String?; let status: String? }
private struct AdmitBody: Encodable { let focus: String; let setting: String; let polling: Bool }
private struct PrepareBody: Encodable { let focus: String; let setting: String; let prepare = true }
private struct StartReply: Decodable { let attempt_id: String; let hidden_tests: [String]? }
private struct ResumeReply: Decodable {
    struct Attempt: Decodable {
        struct Turn: Decodable { let role: String; let text: String }
        struct Coverage: Decodable { let got: Int; let total: Int }
        struct Examined: Decodable { let id: String; let finding: String }
        struct Ordered: Decodable { let id: String; let at: String; let result: String; let abnormal: Bool }
        let attempt_id: String
        let exam_mode: Bool
        let time_limit_minutes: Int?
        let started_at: String
        let transcript: [Turn]
        let revealed_ids: [String]
        // Absent from servers before the labels were returned.
        let revealed: [AskReply.Revealed]?
        let coverage: Coverage
        let examined: [Examined]
        let ordered: [Ordered]
        let hidden_tests: [String]

        var resumed: ResumedAttempt {
            let iso = ISO8601DateFormatter()
            iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let date = { (s: String) in iso.date(from: s) ?? ISO8601DateFormatter().date(from: s) ?? .now }
            return ResumedAttempt(
                id: attempt_id, examMode: exam_mode, timeLimitMinutes: time_limit_minutes, startedAt: date(started_at),
                transcript: transcript.map { .init(fromStudent: $0.role == "student", text: $0.text) },
                revealedIDs: Set(revealed_ids), revealedLabels: (revealed ?? []).map(\.label),
                coverage: (coverage.got, coverage.total),
                examined: examined.map { ($0.id, $0.finding) },
                ordered: ordered.map { .init(id: $0.id, at: date($0.at), result: TestResult(text: $0.result, isAbnormal: $0.abnormal)) },
                hiddenTests: Set(hidden_tests))
        }
    }
    let attempt: Attempt?
}
private struct ExamineReply: Decodable { let finding: String }
private struct OrderReply: Decodable { let result: String; let abnormal: Bool }
private struct TranscribeReply: Decodable { let text: String }
private struct SpeakReply: Decodable { let audio: String }

private struct TranscribeBody: Encodable {
    let action = "transcribe"
    let attempt_id: String
    let audio: String
}

private struct AskReply: Decodable {
    struct Revealed: Decodable { let id: String; let label: String }
    struct Coverage: Decodable { let got: Int; let total: Int }
    let reply: String
    let revealed: [Revealed]
    let revealed_ids: [String]
    let coverage: Coverage

    var answer: PatientAnswer {
        PatientAnswer(reply: reply, revealed: revealed.map { ($0.id, $0.label) }, revealedIDs: revealed_ids,
                      coverage: (coverage.got, coverage.total))
    }
}

/// One line of ask_stream: `text` carries the reply so far, `done` the answer (as AskReply, decoded
/// from the same line), `error` why it failed.
private struct AskStreamLine: Decodable { let type: String; let text: String?; let error: String? }

/// `idle_seconds` is missing from servers that still ended calls after a fixed `seconds`.
private struct LiveCallReply: Decodable { let sdp: String; let call_id: String; let idle_seconds: Int?; let seconds: Int? }
private struct EmptyReply: Decodable {}

private struct VoiceTurnReply: Decodable {
    let reply: String
    let revealed: [AskReply.Revealed]
    let revealed_ids: [String]
    let coverage: AskReply.Coverage
    let flag: String?
    let ended: Bool
}

private struct StartBody: Encodable {
    let action = "start"
    let case_id: String
    let exam_mode: Bool
    let time_limit_minutes: Int?
}

private struct SubmitBody: Encodable {
    let action = "submit"
    let attempt_id: String
    let diagnosis: String
    let differential: [String]
    let plan: String
    /// The student's exam (StudyGoal) and hardest areas (StudyStruggle): see GradingFocus.
    let goal: String?
    let struggles: [String]
}

private struct GradeRow: Decodable {
    struct FeedbackRow: Decodable { let tone: String; let title: String; let detail: String; let covers_miss: String?; let focus: Bool? }
    struct LensRow: Decodable { let title: String; let points: [String] }
    let score: Int
    let diagnosis_correct: Bool
    let diagnosis: String
    let verdict: String
    let rating_delta: Int
    let rating: Int
    struct AboutRow: Decodable {
        let summary_points: [String]?
        let symptoms: [String]?
        let risk_factors: [String]?
    }
    struct DifferentialRow: Decodable {
        let name: String
        let must_not_miss: Bool?
        let why: String?
        let tell_apart: [String]?
        let in_yours: Bool?
    }
    let feedback: [FeedbackRow]
    let missed_red_flags: [MissRow]
    // Teaching fields: absent on grades made before the debrief taught the condition.
    let about: AboutRow?
    let differential: [DifferentialRow]?
    let your_extras: [String]?
    let lens: LensRow?
    struct PartRow: Decodable { let got: Int; let max: Int }
    let breakdown: [String: PartRow]?
    struct PointsRow: Decodable { let got: Int; let max: Int }
    // Absent on grades made before the workup's own points were reported.
    let workup: PointsRow?
    let floor_applied: Bool?

    var grade: Grade {
        Grade(score: score, diagnosisCorrect: diagnosis_correct, diagnosis: diagnosis, verdict: verdict,
              ratingDelta: rating_delta, rating: rating,
              feedback: feedback.map { Feedback(tone: $0.tone == "good" ? .good : .miss, title: $0.title, detail: $0.detail, coversMiss: $0.covers_miss, isFocus: $0.focus ?? false) },
              missedRedFlags: missed_red_flags.map { Miss(flag: $0.flag, why: $0.why) },
              about: about.map { ConditionAbout(summaryPoints: $0.summary_points ?? [], symptoms: $0.symptoms ?? [], riskFactors: $0.risk_factors ?? []) }
                  .flatMap { $0.isEmpty ? nil : $0 },
              differential: (differential ?? []).map {
                  DifferentialReview(name: $0.name, mustNotMiss: $0.must_not_miss ?? false, why: $0.why ?? "",
                                     tellApart: $0.tell_apart ?? [], inYours: $0.in_yours ?? false)
              },
              yourExtras: your_extras ?? [],
              lens: lens.map { ExamLens(title: $0.title, points: $0.points) }.flatMap { $0.points.isEmpty ? nil : $0 },
              breakdown: Dictionary(uniqueKeysWithValues: (breakdown ?? [:]).compactMap { key, part in
                  ScoreCategory(rawValue: key).map { ($0, Points(got: part.got, max: part.max)) }
              }),
              workupPoints: workup.map { (got: $0.got, max: $0.max) },
              floorApplied: floor_applied ?? false)
    }
}
