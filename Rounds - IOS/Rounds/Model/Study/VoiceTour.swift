import Foundation

/// The onboarding tour of voice mode: two exchanges with a sample patient, driven by the student's
/// own voice the way a case is (talk, then pause to send; talk over the patient to cut in). It
/// waits for real speech at every turn and shows the student's own words. The patient's replies
/// are scripted. Pure, so the steps and the turn rules are tested.
struct VoiceTour: Equatable {
    enum Phase: Equatable { case listening, thinking, patient, done }

    /// One scripted exchange: what to say and what the patient answers.
    struct Line: Equatable {
        let question: String
        let reply: String
    }

    static let lines = [
        Line(question: "When did the sore throat start?", reply: "Two days ago. It really hurts to swallow, and I feel so tired…"),
        Line(question: "Any fever or cough?", reply: "I've felt hot and shivery. No cough at all."),
    ]

    private(set) var phase: Phase = .listening
    /// Questions sent so far.
    private(set) var asked = 0
    /// The student cut the patient off during the first answer.
    private(set) var cutIn = false
    /// What the student actually said, one entry per question sent.
    private(set) var heard: [String] = []

    /// A pause this long after speaking sends the turn, as in a case.
    static let quietToSend: TimeInterval = 0.9
    /// Fewer words than this is a cough or a word cut off, not a question.
    static let wordsNeeded = 2
    /// Mic level (0…1) that counts as the student talking over the patient.
    static let cutInLevel: CGFloat = 0.45

    /// Whether what's been heard is a whole turn: enough words, then a pause.
    static func turnIsOver(heard: String, quietFor: TimeInterval) -> Bool {
        heard.split(whereSeparator: \.isWhitespace).count >= wordsNeeded && quietFor >= quietToSend
    }

    /// What the student should say now, or nil when it isn't their turn.
    var toSay: String? {
        switch phase {
        case .listening: Self.lines[min(asked, Self.lines.count - 1)].question
        // Mid-answer the next line is shown too: tap to cut in, then say it.
        case .patient where asked == 1: Self.lines[1].question
        default: nil
        }
    }

    /// The exchanges to show: each question once sent, each answer once the patient has started it.
    var shown: [(question: String, reply: String?)] {
        (0..<asked).map { i in
            let answered = i < asked - 1 || phase == .patient || phase == .done
            return (heard.indices.contains(i) ? heard[i] : Self.lines[i].question, answered ? Self.lines[i].reply : nil)
        }
    }

    /// The student finished a turn: sends what they said. Returns true when it did something.
    @discardableResult
    mutating func send(_ words: String) -> Bool {
        let words = words.trimmingCharacters(in: .whitespacesAndNewlines)
        guard phase == .listening, !words.isEmpty else { return false }
        heard.append(words)
        asked += 1
        phase = .thinking
        return true
    }

    /// The student started talking over the patient's first answer: the floor is theirs.
    @discardableResult
    mutating func interrupt() -> Bool {
        switch phase {
        case .patient where asked == 1:
            cutIn = true
            phase = .listening
            return true
        default:
            return false
        }
    }

    /// The patient starts answering (after a short think).
    mutating func patientAnswers() {
        if phase == .thinking { phase = .patient }
    }

    /// The patient finished the last answer: the tour is done. The first answer only ends when the
    /// student cuts in, so the tour can teach interrupting.
    mutating func patientFinished() {
        if phase == .patient && asked >= Self.lines.count { phase = .done }
    }
}
