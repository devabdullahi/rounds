import Foundation

/// Turns one Realtime API server event (a JSON message on the `oai-events` data channel) into a
/// `LiveVoiceEvent`. Event types the app doesn't use return nil, so new ones never break a call.
/// Pure, so the mapping is tested without a connection.
enum LiveVoiceEventParser {
    static func parse(_ data: Data) -> LiveVoiceEvent? {
        guard let message = try? JSONDecoder().decode(ServerEvent.self, from: data) else { return nil }
        switch message.type {
        case "session.created": return .ready
        case "input_audio_buffer.speech_started": return .studentStartedSpeaking
        case "input_audio_buffer.speech_stopped": return .studentStoppedSpeaking
        case "conversation.item.input_audio_transcription.completed":
            return message.transcript.map { .studentSaid($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
        case "response.output_audio_transcript.delta": return message.delta.map(LiveVoiceEvent.patientWords)
        case "response.output_audio_transcript.done":
            return .patientFinished((message.transcript ?? "").trimmingCharacters(in: .whitespacesAndNewlines))
        case "error":
            // Errors about a single event (a cancel with nothing to cancel) leave the call running.
            let code = message.error?.code ?? ""
            return .failed(message: message.error?.message ?? "Live voice hit an error.", fatal: !recoverable.contains(code))
        default: return nil
        }
    }

    /// Error codes that only reject one client event; the session goes on.
    private static let recoverable: Set<String> = ["response_cancel_not_active", "invalid_value", "unknown_parameter"]
}

/// The fields of a server event the parser reads; everything else is ignored.
private struct ServerEvent: Decodable {
    struct Problem: Decodable { let code: String?; let message: String? }
    let type: String
    let delta: String?
    let transcript: String?
    let error: Problem?
}
