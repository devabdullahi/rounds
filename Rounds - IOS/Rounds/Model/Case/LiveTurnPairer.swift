import Foundation

/// Pairs what the student said with the patient's answer on a live call, so each exchange can be
/// logged as one turn. The two arrive separately and in either order: the student's transcript
/// often lands after the patient has already started (or finished) answering. Pure, so the
/// ordering rules are tested without a call.
struct LiveTurnPairer {
    /// The student's words not yet answered; several utterances before one reply are joined.
    private var question = ""
    /// A reply that finished before the student's transcript arrived.
    private var heldReply: String?

    /// The student's transcribed turn. Returns a finished exchange if its reply was waiting.
    mutating func studentSaid(_ text: String) -> (question: String, reply: String)? {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        question = question.isEmpty ? text : question + " " + text
        guard let reply = heldReply else { return nil }
        heldReply = nil
        return take(reply)
    }

    /// The patient's finished reply. Returns the exchange once the student's words are in.
    mutating func patientFinished(_ reply: String) -> (question: String, reply: String)? {
        guard !question.isEmpty else {
            // Answer first, transcript later: keep it (a second early reply joins the first).
            heldReply = [heldReply, reply].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " ")
            return nil
        }
        return take(reply)
    }

    private mutating func take(_ reply: String) -> (question: String, reply: String) {
        defer { question = "" }
        return (question, reply)
    }
}
