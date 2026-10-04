import SwiftUI
import Observation

struct ChatMessage: Identifiable, Equatable {
    enum Kind: Equatable { case doctor, patient, reveal }
    let id = UUID()
    let kind: Kind
    let text: String
}

enum TestState: Equatable {
    case ordered(Date)
    case ready
}

struct Feedback: Identifiable {
    enum Tone { case good, miss }
    let id = UUID()
    let tone: Tone
    let title: String
    let detail: String
    var coversMiss: String? = nil   // a Miss flag this note already explains
}

struct Grade {
    let score: Int
    let diagnosisCorrect: Bool
    let verdict: String
    let ratingDelta: Int
    let feedback: [Feedback]
    let missedRedFlags: [Miss]
}

/// One run through a case: brief → interview → workup → diagnosis → debrief.
@Observable
final class CaseSession {
    let clinical: ClinicalCase
    var examMode = false

    private(set) var startedAt: Date?
    private(set) var messages: [ChatMessage] = []
    private(set) var revealed: Set<String> = []
    private(set) var examined: [String] = []
    private(set) var tests: [String: TestState] = [:]
    private(set) var testOrder: [String] = []
    var isPatientTyping = false

    var diagnosis = ""
    var differential: [String]
    var plan = ""
    private(set) var grade: Grade?

    init(clinical: ClinicalCase = .chestPain) {
        self.clinical = clinical
        self.differential = clinical.startingDifferential
        self.timeLimitMinutes = clinical.minutes
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

    // MARK: Interview

    func ask(_ raw: String) {
        let question = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty, !isPatientTyping else { return }
        startClockIfNeeded()
        withAnimation(Springs.slide) {
            messages.append(ChatMessage(kind: .doctor, text: question))
            isPatientTyping = true
        }

        let q = question.lowercased()
        let hits = clinical.facts.filter { fact in fact.keywords.contains { q.contains($0) } }
        let delay = 0.7 + Double.random(in: 0...0.5)

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(delay))
            withAnimation(Springs.slide) {
                isPatientTyping = false
                if hits.isEmpty {
                    messages.append(ChatMessage(kind: .patient, text: clinical.fallbackReply))
                } else {
                    messages.append(ChatMessage(kind: .patient, text: hits.map(\.reply).joined(separator: " ")))
                    let fresh = hits.filter { !revealed.contains($0.id) }
                    fresh.forEach { revealed.insert($0.id) }
                    if !fresh.isEmpty && !examMode {
                        messages.append(ChatMessage(kind: .reveal, text: "Revealed: " + fresh.map(\.label).joined(separator: ", ")))
                    }
                }
            }
        }
    }

    /// Key history areas uncovered so far (onset, character, radiation…), without saying which remain.
    var historyCoverage: (got: Int, total: Int) {
        let key = clinical.facts.filter(\.isKeyHistory)
        return (key.filter { revealed.contains($0.id) }.count, key.count)
    }

    // MARK: Examination

    func examine(_ id: String) {
        guard !examined.contains(id) else { return }
        startClockIfNeeded()
        withAnimation(Springs.slide) { examined.append(id) }
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
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(test.turnaround))
            withAnimation(Springs.card) { tests[test.id] = .ready }
        }
    }

    // MARK: Grading

    func submit() -> Grade {
        if let grade { return grade }
        let c = clinical
        let dx = diagnosis.lowercased()
        let dxCorrect = c.acceptedDiagnoses.contains { dx.contains($0) }

        var score = 0
        var feedback: [Feedback] = []
        var missed: [Miss] = []

        // Diagnosis — 35
        if dxCorrect { score += 35 }
        else {
            feedback.append(Feedback(tone: .miss, title: "The diagnosis was \(c.canonicalDiagnosis)",
                                     detail: "Heavy central pain radiating to the arm with inferior ST elevation and a raised troponin."))
        }

        // History coverage — 25
        let key = c.facts.filter(\.isKeyHistory)
        let gotKey = key.filter { revealed.contains($0.id) }
        score += Int((Double(gotKey.count) / Double(key.count) * 25).rounded())
        if let gap = key.first(where: { !revealed.contains($0.id) }) {
            feedback.append(Feedback(tone: .miss, title: "History gap: \(gap.label)",
                                     detail: "You never asked about it. A focused chest pain history covers onset, character, radiation, associated symptoms, risk factors and past history."))
        }

        // Red flags — 20: rule out dissection before antiplatelets
        let dissectionScreened = revealed.contains("back") || examined.contains("armbp")
        if dissectionScreened { score += 12 }
        else {
            missed.append(Miss(flag: "Tearing back pain", why: "Dissection mimics MI. Ask, and compare arm pressures, before giving aspirin."))
            feedback.insert(Feedback(tone: .miss, title: "You never ruled out dissection",
                                     detail: "Ask about tearing back pain and compare arm pressures before giving aspirin.",
                                     coversMiss: "Tearing back pain"), at: 0)
        }
        if revealed.contains("drugs") { score += 4 } else { missed.append(Miss(flag: "Cocaine use", why: "Cocaine chest pain changes management: no beta-blockers.")) }
        if examined.contains("pulses") { score += 4 } else { missed.append(Miss(flag: "Pulse deficit", why: "Unequal pulses point to dissection. Check radials and femorals.")) }

        // Tests — 15
        if tests["ecg"] != nil { score += 8 }
        if testOrder.first == "ecg" {
            score += 2
            feedback.append(Feedback(tone: .good, title: "ECG first. Sharp.", detail: "Fast, cheap, and the right first test."))
        } else if tests["ecg"] == nil {
            feedback.append(Feedback(tone: .miss, title: "No ECG", detail: "Every chest pain gets a 12-lead within 10 minutes."))
        }
        if tests["trop"] != nil { score += 5 }
        if tests["ctpa"] != nil {
            score -= 5
            feedback.append(Feedback(tone: .miss, title: "CTPA wasn't indicated",
                                     detail: "Low PE probability and a diagnostic ECG. It cost $900 and 25 minutes of heart muscle."))
        }
        if spent > c.budget { score -= 5 }

        // Plan — 5
        let p = plan.lowercased()
        if c.planKeywords.contains(where: { p.contains($0) }) { score += 5 }
        else {
            feedback.append(Feedback(tone: .miss, title: "Plan missing reperfusion",
                                     detail: "Aspirin and urgent primary PCI. Time is muscle."))
        }

        score = min(100, max(0, score))
        let verdict: String
        switch (dxCorrect, score) {
        case (true, 85...): verdict = "Textbook workup"
        case (true, _):     verdict = "Right diagnosis, incomplete path"
        case (false, _):    verdict = "Missed diagnosis"
        }
        let g = Grade(score: score, diagnosisCorrect: dxCorrect, verdict: verdict,
                      ratingDelta: (score - 60) / 2, feedback: Array(feedback.prefix(4)), missedRedFlags: missed)
        grade = g
        return g
    }

    #if DEBUG
    func debugInject(messages: [ChatMessage], revealed: Set<String>, examined: [String], tests: [String], pending: Set<String>) {
        startedAt = Date.now.addingTimeInterval(-205)
        self.messages = messages
        self.revealed = revealed
        self.examined = examined
        for id in tests {
            self.tests[id] = pending.contains(id) ? .ordered(.now) : .ready
            testOrder.append(id)
            if pending.contains(id), let t = clinical.tests.first(where: { $0.id == id }) {
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(t.turnaround))
                    self.tests[id] = .ready
                }
            }
        }
    }
    #endif
}
