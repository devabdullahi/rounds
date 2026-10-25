import Foundation

/// Why the student downloaded Rounds, asked once in onboarding right after their exam goal. Saved
/// with the other answers for product research; the app doesn't change anything based on it yet.
enum DownloadReason: String, CaseIterable, Identifiable {
    case confidence, differentials, rotations, exams

    static let storageKey = "downloadReason"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .confidence: "Talk to patients with confidence"
        case .differentials: "Build better differentials"
        case .rotations: "Get ready for rotations"
        case .exams: "Score higher on exams"
        }
    }

    /// Reads the stored raw value; nil when nothing (or something unknown) was saved.
    init?(stored: String) { self.init(rawValue: stored) }
}
