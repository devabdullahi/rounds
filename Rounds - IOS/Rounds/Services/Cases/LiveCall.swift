import Foundation

/// A live voice call the server opened with OpenAI: its SDP answer, its id, and how long it may run.
struct LiveCall: Equatable, Sendable {
    let answer: String
    let id: String
    let seconds: Int
}
