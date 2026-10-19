import Foundation

/// The audio connection of a live voice call. Live: `RealtimeClient` (WebRTC to OpenAI); tests and
/// previews: `MockLiveVoiceTransport`. Views and models never see WebRTC types.
@MainActor
protocol LiveVoiceTransport: AnyObject {
    /// Everything that happens on the call, until it ends.
    var events: AsyncStream<LiveVoiceEvent> { get }
    /// Opens the mic and the connection. `exchange` takes the local SDP offer and returns the
    /// answer (through our server, which holds the API key).
    func connect(exchange: @escaping @Sendable (String) async throws -> String) async throws
    /// Stops the patient mid-reply: the student tapped to take the floor.
    func cutOffPatient()
    func disconnect()
}
