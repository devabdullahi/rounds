import Foundation

/// What happens on a live voice call, as the app cares about it. Decoded from the Realtime API's
/// data-channel events by `LiveVoiceEventParser`; transport changes come from `RealtimeClient`.
enum LiveVoiceEvent: Equatable, Sendable {
    /// The session is live and the patient can hear the student.
    case ready
    case studentStartedSpeaking
    case studentStoppedSpeaking
    /// What the student said in one turn, transcribed by the server.
    case studentSaid(String)
    /// More of the patient's words as they speak.
    case patientWords(String)
    /// The patient's reply ended (finished or cut off): everything they said in it.
    case patientFinished(String)
    /// Mic and patient loudness, 0…1, for the orb.
    case levels(mic: Double, patient: Double)
    /// The connection dropped or failed; the call is over.
    case disconnected
    /// The API reported an error. `fatal` ones end the call.
    case failed(message: String, fatal: Bool)
}
