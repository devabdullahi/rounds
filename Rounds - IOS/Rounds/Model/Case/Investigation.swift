import Foundation

/// An orderable test. Its result arrives from the server when ordered.
struct Investigation: Identifiable, Hashable {
    let id: String
    let name: String
    let detail: String
    let cost: Int
    var delaysCareMinutes = 0  // time added before definitive treatment

    /// The kind of test without how long it takes: "Bloods · 4 min" → "Bloods". Results arrive as
    /// soon as the server sends them, so a wait time would only mislead.
    var kind: String { Self.withoutDuration(detail) }

    static func withoutDuration(_ detail: String) -> String {
        detail.components(separatedBy: "·")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && $0.range(of: #"^~?\d+(\.\d+)?\s*(s|sec|secs|seconds?|m|min|mins|minutes?|h|hr|hrs|hours?)$"#, options: [.regularExpression, .caseInsensitive]) == nil }
            .joined(separator: " · ")
    }
}
