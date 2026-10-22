import Foundation

/// The onboarding tour of voice mode: two scripted exchanges with a sample patient, driven by the
/// student tapping the orb the way they will in a case (tap to send what you said, tap to cut the
/// patient off). It waits on the student at every turn. Pure, so the steps are tested.
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
            return (Self.lines[i].question, answered ? Self.lines[i].reply : nil)
        }
    }

    /// A tap on the orb. Returns true when it did something (the screen plays a haptic).
    @discardableResult
    mutating func tap() -> Bool {
        switch phase {
        case .listening:
            asked += 1
            phase = .thinking
            return true
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
