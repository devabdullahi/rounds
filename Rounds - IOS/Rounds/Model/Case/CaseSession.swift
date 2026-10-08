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
    private(set) var startedAt: Date?
    private(set) var messages: [ChatMessage] = []
    private(set) var revealed: Set<String> = []
    private(set) var examined: [String] = []
    /// Findings returned by the server, by maneuver id.
    private(set) var findings: [String: String] = [:]
    private(set) var tests: [String: TestState] = [:]
    private(set) var testOrder: [String] = []
    /// Results returned by the server, by test id. Shown once the in-app turnaround has passed.
    private(set) var results: [String: TestResult] = [:]
    private(set) var coverage: (got: Int, total: Int) = (0, 0)
    /// Questions, exams and tests in the order they happened.
    private(set) var timeline: [TimelineEvent] = []
    var isPatientTyping = false

    var diagnosis = ""
    var differential: [String] = []
    var plan = ""
    private(set) var grade: Grade?

    init(clinical: ClinicalCase, service: any CaseService) {
        self.clinical = clinical
        self.service = service
        self.timeLimitMinutes = clinical.minutes
        self.coverage = (0, clinical.keyHistoryTotal)
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

    /// Creates the attempt on the server the first time the student does anything.
    private func attempt() async throws -> String {
        if let attemptID { return attemptID }
        let id = try await service.start(bed: clinical.bed, examMode: examMode, timeLimitMinutes: timeLimitMinutes)
        attemptID = id
        return id
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
                let answer = try await service.ask(attempt: attempt(), question: question)
                withAnimation(Springs.slide) {
                    isPatientTyping = false
                    messages.append(ChatMessage(kind: .patient, text: answer.reply))
                    revealed = Set(answer.revealedIDs)
                    coverage = answer.coverage
                    if !answer.revealed.isEmpty && !examMode {
                        messages.append(ChatMessage(kind: .reveal, text: "Revealed: " + answer.revealed.map(\.label).joined(separator: ", ")))
                    }
                }
            } catch {
                withAnimation(Springs.slide) {
                    isPatientTyping = false
                    messages.append(ChatMessage(kind: .problem, text: error.localizedDescription))
                }
            }
        }
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

    var spent: Int {
        clinical.tests.filter { tests[$0.id] != nil }.reduce(0) { $0 + $1.cost }
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
                async let result = service.order(attempt: id, test: test.id)
                try await Task.sleep(for: .seconds(test.turnaround))
                let r = try await result
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
    func submit() async throws -> Grade {
        if let grade { return grade }
        let g = try await service.submit(attempt: attempt(), diagnosis: diagnosis, differential: differential, plan: plan)
        grade = g
        return g
    }
}
