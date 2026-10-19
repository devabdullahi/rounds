import Foundation

/// One spoken exchange of a live call, as the server logged it.
struct VoiceTurnOutcome: Sendable {
    let answer: PatientAnswer
    /// The reply, already heard, named the diagnosis or a medical detail that isn't in the case.
    let brokeRule: Bool
    /// The server ended the call (out of time, or too many inappropriate questions).
    let ended: Bool
}
