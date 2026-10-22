import Foundation

/// A live voice call the server opened with OpenAI: its SDP answer, its id, and how long it may go
/// without a finished exchange before it's hung up. There's no limit on how long a call runs.
struct LiveCall: Equatable, Sendable {
    let answer: String
    let id: String
    let idleSeconds: Int

    /// The server's idle window (`IDLE_SECONDS` in supabase/functions/_shared/realtime.ts), for a
    /// reply that doesn't say.
    static let defaultIdleSeconds = 120
}
