import Foundation

/// A scripted live call for tests and previews: connects (or fails) without audio, and plays the
/// events a test pushes.
@MainActor
final class MockLiveVoiceTransport: LiveVoiceTransport {
    let events: AsyncStream<LiveVoiceEvent>
    private let continuation: AsyncStream<LiveVoiceEvent>.Continuation
    private let failure: Error?
    private(set) var cutOffs = 0
    private(set) var disconnected = false

    init(failing failure: Error? = nil) {
        (events, continuation) = AsyncStream.makeStream(of: LiveVoiceEvent.self)
        self.failure = failure
    }

    func connect(exchange: @escaping @Sendable (String) async throws -> String) async throws {
        if let failure { throw failure }
        _ = try await exchange("v=0 mock offer")
        continuation.yield(.ready)
    }

    func cutOffPatient() { cutOffs += 1 }

    func disconnect() {
        disconnected = true
        continuation.finish()
    }

    /// Plays one event as if it came from the call.
    func push(_ event: LiveVoiceEvent) { continuation.yield(event) }
}
