import SwiftUI
import Observation

/// One run through a case: brief → interview → workup → diagnosis → debrief.
/// Every action goes through `CaseService`; the attempt starts on the first action, after the
/// student has chosen exam mode and the clock on the door note.
@MainActor
@Observable
final class CaseSession {
    let clinical: ClinicalCase
    private let service: any CaseService
    var examMode = false

    private(set) var attemptID: String?
    /// True when this session continues an attempt the student left; the case opens on the interview.
    private(set) var resumed = false
    /// The server has this attempt in `examMode`, so the mode can't change any more: switching after
    /// Practice hints would be graded as Exam, and a resumed case would come back in its old mode.
    var modeLocked: Bool { attemptID != nil }
    /// The attempt start in flight, shared by every action that arrives before it returns.
    @ObservationIgnored private var starting: Task<AttemptStart, Error>?
    /// Tests left off this attempt's menu (practice mode hides the ones the case doesn't call for).
    private(set) var hiddenTests: Set<String> = []
    /// False until the attempt has started and the server has said which tests to hide.
    private(set) var menuReady = false
    private(set) var startedAt: Date?
    private(set) var messages: [ChatMessage] = []
    private(set) var revealed: Set<String> = []
    private(set) var examined: [String] = []
    /// Findings returned by the server, by maneuver id.
    private(set) var findings: [String: String] = [:]
    private(set) var tests: [String: TestState] = [:]
    private(set) var testOrder: [String] = []
    /// Results returned by the server, by test id, shown as soon as they arrive.
    private(set) var results: [String: TestResult] = [:]
    private(set) var coverage: (got: Int, total: Int) = (0, 0)
    /// Questions, exams and tests in the order they happened.
    private(set) var timeline: [TimelineEvent] = []
    var isPatientTyping = false

    var diagnosis = ""
    var differential: [String] = []
    var plan = ""
    private(set) var grade: Grade?
    /// The grading request in flight, shared by the hand-off and the debrief.
    @ObservationIgnored private var grading: Task<Grade, Error>?

    init(clinical: ClinicalCase, service: any CaseService) {
        self.clinical = clinical
        self.service = service
        self.timeLimitMinutes = clinical.minutes
        self.coverage = (0, clinical.keyHistoryTotal)
    }

    /// Picks up an attempt the student left: the conversation, what it uncovered, exam findings,
    /// test results and the clock, so the progress bars and chat are as they left them. Exam steps
    /// and tests go on the timeline at their own times when known (tests), else at the start.
    func restore(_ a: ResumedAttempt) {
        attemptID = a.id
        resumed = true
        examMode = a.examMode
        timeLimitMinutes = a.timeLimitMinutes
        hiddenTests = a.hiddenTests
        menuReady = true
        startedAt = a.startedAt
        messages = a.transcript.map { ChatMessage(kind: $0.fromStudent ? .doctor : .patient, text: $0.text) }
        revealed = a.revealedIDs
        if a.coverage.total > 0 { coverage = a.coverage }
        examined = a.examined.map(\.id)
        findings = Dictionary(a.examined.map { ($0.id, $0.finding) }, uniquingKeysWith: { first, _ in first })
        testOrder = a.ordered.map(\.id)
        tests = Dictionary(a.ordered.map { ($0.id, TestState.ready) }, uniquingKeysWith: { first, _ in first })
        results = Dictionary(a.ordered.map { ($0.id, $0.result) }, uniquingKeysWith: { first, _ in first })
        timeline = a.transcript.filter(\.fromStudent).map { TimelineEvent(at: a.startedAt, kind: .question, text: $0.text) }
            + a.examined.compactMap { e in clinical.exam.first { $0.id == e.id }.map { TimelineEvent(at: a.startedAt, kind: .exam, text: $0.title) } }
            + a.ordered.compactMap { o in clinical.tests.first { $0.id == o.id }.map { TimelineEvent(at: o.at, kind: .test, text: "Ordered \($0.name)") } }
    }

    // MARK: Clock

    /// Chosen on the door note before the clock starts. nil = untimed.
    var timeLimitMinutes: Int?
    var isTimed: Bool { timeLimitMinutes != nil }
    var totalSeconds: TimeInterval { TimeInterval((timeLimitMinutes ?? 0) * 60) }

    func elapsed(at date: Date) -> TimeInterval {
        guard let startedAt else { return 0 }
        return date.timeIntervalSince(startedAt)
    }

    func startClockIfNeeded() {
        if startedAt == nil { startedAt = .now }
    }

    func remaining(at date: Date) -> TimeInterval {
        guard let startedAt else { return totalSeconds }
        return max(0, totalSeconds - date.timeIntervalSince(startedAt))
    }

    static func format(_ t: TimeInterval) -> String {
        let s = Int(t.rounded(.up))
        return String(format: "%02d:%02d", s / 60, s % 60)
    }

    /// Creates the attempt on the server the first time the student does anything. A question, an
    /// exam and a test can all fire before the first start returns, so they share one start: two
    /// starts would split the case across two attempts and the grade would miss half the work.
    private func attempt() async throws -> String {
        if let attemptID { return attemptID }
        if let starting { return try await starting.value.id }
        let task = Task { try await service.start(bed: clinical.bed, examMode: examMode, timeLimitMinutes: timeLimitMinutes) }
        starting = task
        do {
            let started = try await task.value
            attemptID = started.id
            hiddenTests = started.hiddenTests
            menuReady = true
            return started.id
        } catch {
            starting = nil   // a failed start can be retried by the next action
            throw error
        }
    }

    // MARK: Interview

    func ask(_ raw: String) {
        let question = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty, !isPatientTyping else { return }
        startClockIfNeeded()
        withAnimation(Springs.slide) {
            messages.append(ChatMessage(kind: .doctor, text: question))
            isPatientTyping = true
        }
        timeline.append(TimelineEvent(at: .now, kind: .question, text: question))
        Task {
            do {
                show(try await service.ask(attempt: attempt(), question: question))
            } catch {
                withAnimation(Springs.slide) {
                    isPatientTyping = false
                    messages.append(ChatMessage(kind: .problem, text: error.localizedDescription))
                }
            }
        }
    }

    // MARK: Voice

    /// The patient's latest reply, spoken in their voice.
    func spokenReply() async throws -> Data {
        try await service.speakLatestReply(attempt: attempt())
    }

    // MARK: Live voice

    /// Opens a live voice call for the phone's WebRTC offer. A refusal (today's live voice time is
    /// used up, or the call couldn't start) is said in the chat, since the screen then quietly
    /// switches to turn-by-turn voice.
    func startLiveCall(offer: String) async throws -> LiveCall {
        startClockIfNeeded()
        do {
            return try await service.startLiveCall(attempt: attempt(), offer: offer)
        } catch {
            // A server without live voice yet ("Unknown action.") just means turn-by-turn: nothing to say.
            if (error as? CaseServiceError)?.message != "Unknown action." {
                withAnimation(Springs.slide) { messages.append(ChatMessage(kind: .problem, text: error.localizedDescription)) }
            }
            throw error
        }
    }

    /// One finished spoken exchange: shown in the chat at once (it was already heard), then logged
    /// so it reveals facts and counts toward the grade. Returns true when the server ended the call.
    func logLiveTurn(call: String, question: String, reply: String) async -> Bool {
        withAnimation(Springs.slide) {
            messages.append(ChatMessage(kind: .doctor, text: question))
            if !reply.isEmpty { messages.append(ChatMessage(kind: .patient, text: reply)) }
        }
        timeline.append(TimelineEvent(at: .now, kind: .question, text: question))
        do {
            let outcome = try await service.logVoiceTurn(attempt: attempt(), call: call, question: question, reply: reply)
            let answer = outcome.answer
            withAnimation(Springs.slide) {
                revealed = Set(answer.revealedIDs)
                coverage = answer.coverage
                if !answer.revealed.isEmpty && !examMode {
                    messages.append(ChatMessage(kind: .reveal, text: "Revealed: " + answer.revealed.map(\.label).joined(separator: ", ")))
                }
                if outcome.brokeRule {
                    messages.append(ChatMessage(kind: .problem, text: "The patient said something that isn't part of this case. Don't rely on it."))
                }
            }
            return outcome.ended
        } catch {
            withAnimation(Springs.slide) { messages.append(ChatMessage(kind: .problem, text: error.localizedDescription)) }
            return false
        }
    }

    /// The live call ended on the phone; the server hangs up its side. Best effort.
    func endLiveCall(_ call: String) {
        guard let attemptID else { return }
        Task { [service] in try? await service.endLiveCall(attempt: attemptID, call: call) }
    }

    /// A spoken question: asked, shown and answered like a typed one, and the reply's voice comes back
    /// in the same response. Returns the reply and its audio, or nil when the question failed (the
    /// error shows in the chat).
    func askAloud(_ raw: String) async -> (reply: String, audio: AsyncThrowingStream<Data, Error>)? {
        let question = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty, !isPatientTyping else { return nil }
        startClockIfNeeded()
        withAnimation(Springs.slide) {
            messages.append(ChatMessage(kind: .doctor, text: question))
            isPatientTyping = true
        }
        timeline.append(TimelineEvent(at: .now, kind: .question, text: question))
        do {
            let spoken: SpokenAnswer
            do {
                spoken = try await service.askAloud(attempt: attempt(), question: question)
            } catch let error as CaseServiceError where error.message == Self.unknownAction {
                // A server without ask_aloud yet: ask as typed, with no audio, so voice falls back
                // to its separate spoken-reply request instead of failing the question.
                let answer = try await service.ask(attempt: attempt(), question: question)
                spoken = SpokenAnswer(answer: answer, audio: AsyncThrowingStream { $0.finish(throwing: error) })
            }
            show(spoken.answer)
            return (spoken.answer.reply, spoken.audio)
        } catch {
            withAnimation(Springs.slide) {
                isPatientTyping = false
                messages.append(ChatMessage(kind: .problem, text: error.localizedDescription))
            }
            return nil
        }
    }

    /// What the server says to an action it doesn't have yet (an app newer than its backend).
    private static let unknownAction = "Unknown action."

    /// The patient's answer in the chat: the reply, what it revealed, and the coverage.
    private func show(_ answer: PatientAnswer) {
        withAnimation(Springs.slide) {
            isPatientTyping = false
            messages.append(ChatMessage(kind: .patient, text: answer.reply))
            revealed = Set(answer.revealedIDs)
            coverage = answer.coverage
            if !answer.revealed.isEmpty && !examMode {
                messages.append(ChatMessage(kind: .reveal, text: "Revealed: " + answer.revealed.map(\.label).joined(separator: ", ")))
            }
        }
    }

    /// The same, as PCM chunks that can play while the rest is still being made.
    func streamedReply() async throws -> AsyncThrowingStream<Data, Error> {
        try await service.streamLatestReply(attempt: attempt())
    }

    /// Key history areas uncovered so far (onset, character, radiation…), without saying which remain.
    var historyCoverage: (got: Int, total: Int) { coverage }

    // MARK: Examination

    func examine(_ id: String) {
        guard !examined.contains(id) else { return }
        startClockIfNeeded()
        withAnimation(Springs.slide) { examined.append(id) }
        if let m = clinical.exam.first(where: { $0.id == id }) {
            timeline.append(TimelineEvent(at: .now, kind: .exam, text: m.title))
        }
        Task {
            do {
                let finding = try await service.examine(attempt: attempt(), maneuver: id)
                withAnimation(Springs.slide) { findings[id] = finding }
            } catch {
                withAnimation(Springs.slide) { examined.removeAll { $0 == id } }
                messages.append(ChatMessage(kind: .problem, text: error.localizedDescription))
            }
        }
    }

    // MARK: Investigations

    /// The tests the student can order: the case's menu without the hidden ones.
    var menu: [Investigation] { clinical.tests.filter { !hiddenTests.contains($0.id) } }

    /// Tests ordered out of those on the menu, for the workup's progress bar.
    /// Exam steps done out of the case's exam, for the workup's progress card.
    var examDone: (done: Int, total: Int) { (examined.count, clinical.exam.count) }

    /// Exam steps and tests it takes before "I'm ready to diagnose" becomes the main action:
    /// earlier, it would invite skipping the workup the tab is for.
    static let workupBeforeDiagnosis = 2
    var hasWorkedUp: Bool { examined.count + testOrder.count >= Self.workupBeforeDiagnosis }

    var testsTaken: (done: Int, total: Int) {
        let menuIDs = Set(menu.map(\.id))
        return (tests.keys.filter(menuIDs.contains).count, menuIDs.count)
    }

    /// Starts the attempt (if no action has yet) so the menu knows what to hide. A failed start
    /// leaves the menu waiting; the next action retries it.
    func loadMenu() async {
        _ = try? await attempt()
    }

    func order(_ test: Investigation) {
        guard tests[test.id] == nil else { return }
        startClockIfNeeded()
        withAnimation(Springs.card) {
            tests[test.id] = .ordered(.now)
            testOrder.append(test.id)
        }
        timeline.append(TimelineEvent(at: .now, kind: .test, text: "Ordered \(test.name)"))
        Task {
            do {
                let id = try await attempt()
                let r = try await service.order(attempt: id, test: test.id)
                withAnimation(Springs.card) {
                    results[test.id] = r
                    tests[test.id] = .ready
                }
            } catch {
                withAnimation(Springs.card) {
                    tests[test.id] = nil
                    testOrder.removeAll { $0 == test.id }
                }
                messages.append(ChatMessage(kind: .problem, text: error.localizedDescription))
            }
        }
    }

    // MARK: Grading

    /// Sends the diagnosis and plan; the server grades from everything logged on the attempt.
    /// Grades the case once. The hand-off starts it while the attending "reads", and the debrief
    /// awaits the same request, so the case is never submitted twice.
    func submit() async throws -> Grade {
        if let grade { return grade }
        if let grading { return try await grading.value }
        let task = Task { try await service.submit(attempt: attempt(), diagnosis: diagnosis, differential: differential, plan: plan) }
        grading = task
        do {
            let g = try await task.value
            grade = g
            return g
        } catch {
            grading = nil   // the debrief can try again
            throw error
        }
    }
}

/// Lets a running case drive `.fullScreenCover(item:)`: each session is its own identity.
extension CaseSession: Identifiable {
    nonisolated var id: ObjectIdentifier { ObjectIdentifier(self) }
}
