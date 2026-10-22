import Foundation

/// How sure the student feels diagnosing a patient today, 1–10, asked once in onboarding. The
/// reality check reads it back in the student's own words; nothing else is inferred from it.
struct DiagnosisConfidence: Equatable {
    static let storageKey = "diagnosisConfidence"
    static let range = 1...10
    /// At or above this, the student already feels sure; below it, there's a gap to close.
    static let sure = 8

    let value: Int

    /// Reads the stored value; nil when nothing (or something out of range) was saved.
    init?(stored: Int) {
        guard Self.range.contains(stored) else { return nil }
        value = stored
    }

    var feelsSure: Bool { value >= Self.sure }

    /// The reality check's headline: their number, said plainly, in a few words.
    var headline: String { feelsSure ? "Keep that \(value) sharp." : "A \(value) won't cut it." }
}
