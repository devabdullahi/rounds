import Foundation

/// One step of a patient answer shown while it's written: the reply so far, then the finished answer.
/// The finished reply is the one to keep; it may differ from what was shown along the way (the
/// server swaps a reply that fails its checks).
enum AnswerProgress: Sendable {
    /// The whole reply so far, not just the newest words.
    case writing(String)
    case done(PatientAnswer)
}
