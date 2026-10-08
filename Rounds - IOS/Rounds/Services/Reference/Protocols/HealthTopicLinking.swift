import Foundation

protocol HealthTopicLinking: Sendable {
    /// Patient-education pages for a diagnosis name or ICD-10 code.
    func topics(for diagnosis: String) async throws -> [HealthTopic]
}
