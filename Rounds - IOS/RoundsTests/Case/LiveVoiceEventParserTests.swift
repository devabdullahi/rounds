import Foundation
import Testing
@testable import Rounds

/// The Realtime API's data-channel events, mapped to what the app does with them.
struct LiveVoiceEventParserTests {
    @Test(arguments: [
        (#"{"type":"session.created","session":{}}"#, LiveVoiceEvent.ready),
        (#"{"type":"input_audio_buffer.speech_started","audio_start_ms":10}"#, .studentStartedSpeaking),
        (#"{"type":"input_audio_buffer.speech_stopped"}"#, .studentStoppedSpeaking),
        (#"{"type":"conversation.item.input_audio_transcription.completed","item_id":"i1","transcript":" Any fever? "}"#, .studentSaid("Any fever?")),
        (#"{"type":"response.output_audio_transcript.delta","delta":"No, "}"#, .patientWords("No, ")),
        (#"{"type":"response.output_audio_transcript.done","transcript":"No, none."}"#, .patientFinished("No, none.")),
        (#"{"type":"error","error":{"code":"response_cancel_not_active","message":"Nothing to cancel"}}"#, .failed(message: "Nothing to cancel", fatal: false)),
        (#"{"type":"error","error":{"code":"session_expired","message":"Expired"}}"#, .failed(message: "Expired", fatal: true)),
    ])
    func mapsServerEvents(json: String, expected: LiveVoiceEvent) {
        #expect(LiveVoiceEventParser.parse(Data(json.utf8)) == expected)
    }

    @Test(arguments: [#"{"type":"response.output_audio.delta","delta":"AAAA"}"#, #"{"type":"rate_limits.updated"}"#, "not json"])
    func ignoresEverythingElse(json: String) {
        #expect(LiveVoiceEventParser.parse(Data(json.utf8)) == nil)
    }
}
