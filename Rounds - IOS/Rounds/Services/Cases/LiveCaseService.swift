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
            // Only a device with no session at all starts a guest one. Any other failure (a refresh
            // that didn't go through) is thrown, so a signed-in student is never silently swapped
            // into an empty guest account.
            _ = try await client.auth.signInAnonymously()
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

    func admit(focus: StudyFocus) async throws -> AdmitOutcome {
        let reply: AdmitReply = try await invoke("generate-case", ["focus": focus.stored])
        if let bed = reply.case_id { return .admitted(bed: bed) }
        guard reply.status == "preparing" else { throw CaseServiceError(message: "The server sent no patient.") }
        return .preparing
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

    func ask(attempt: String, question: String) async throws -> PatientAnswer {
        let r: AskReply = try await invoke("case-session", ["action": "ask", "attempt_id": attempt, "question": question])
        return PatientAnswer(reply: r.reply, revealed: r.revealed.map { ($0.id, $0.label) }, revealedIDs: r.revealed_ids,
                             coverage: (r.coverage.got, r.coverage.total))
    }

    func examine(attempt: String, maneuver: String) async throws -> String {
        let r: ExamineReply = try await invoke("case-session", ["action": "examine", "attempt_id": attempt, "maneuver_id": maneuver])
        return r.finding
    }

    func order(attempt: String, test: String) async throws -> TestResult {
        let r: OrderReply = try await invoke("case-session", ["action": "order", "attempt_id": attempt, "test_id": test])
        return TestResult(text: r.result, isAbnormal: r.abnormal)
    }

    func submit(attempt: String, diagnosis: String, differential: [String], plan: String) async throws -> Grade {
        let r: GradeRow = try await invoke("case-session", SubmitBody(attempt_id: attempt, diagnosis: diagnosis, differential: differential, plan: plan))
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
            meta: [sex, "\(age)", rotation?.label].compactMap { $0 }.joined(separator: " · "),
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
                                                 turnaround: $0.turnaround_s, delaysCareMinutes: $0.delays_care_min ?? 0) },
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
            feedback: grade.feedback.map { Feedback(tone: $0.tone == "good" ? .good : .miss, title: $0.title, detail: $0.detail, coversMiss: $0.covers_miss) },
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
private struct StartReply: Decodable { let attempt_id: String; let hidden_tests: [String]? }
private struct ExamineReply: Decodable { let finding: String }
private struct OrderReply: Decodable { let result: String; let abnormal: Bool }

private struct AskReply: Decodable {
    struct Revealed: Decodable { let id: String; let label: String }
    struct Coverage: Decodable { let got: Int; let total: Int }
    let reply: String
    let revealed: [Revealed]
    let revealed_ids: [String]
    let coverage: Coverage
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
}

private struct GradeRow: Decodable {
    struct FeedbackRow: Decodable { let tone: String; let title: String; let detail: String; let covers_miss: String? }
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

    var grade: Grade {
        Grade(score: score, diagnosisCorrect: diagnosis_correct, diagnosis: diagnosis, verdict: verdict,
              ratingDelta: rating_delta, rating: rating,
              feedback: feedback.map { Feedback(tone: $0.tone == "good" ? .good : .miss, title: $0.title, detail: $0.detail, coversMiss: $0.covers_miss) },
              missedRedFlags: missed_red_flags.map { Miss(flag: $0.flag, why: $0.why) },
              about: about.map { ConditionAbout(summaryPoints: $0.summary_points ?? [], symptoms: $0.symptoms ?? [], riskFactors: $0.risk_factors ?? []) }
                  .flatMap { $0.isEmpty ? nil : $0 },
              differential: (differential ?? []).map {
                  DifferentialReview(name: $0.name, mustNotMiss: $0.must_not_miss ?? false, why: $0.why ?? "",
                                     tellApart: $0.tell_apart ?? [], inYours: $0.in_yours ?? false)
              },
              yourExtras: your_extras ?? [])
    }
}
