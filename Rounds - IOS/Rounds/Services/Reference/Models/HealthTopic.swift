import Foundation

/// A plain-language page to read after a case.
struct HealthTopic: Identifiable, Hashable, Sendable {
    let title: String
    let summary: String
    let url: URL
    var id: URL { url }
}
