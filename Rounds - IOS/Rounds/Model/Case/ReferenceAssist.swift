import Foundation
import Observation

/// Reference lookups for the case screens: diagnosis autocomplete and recognised drugs on the
/// Diagnosis screen, "Learn more" pages on the Debrief. Views call these as text changes
/// (from `.task(id:)`, which cancels stale calls); results are display-only and never graded.
@MainActor
@Observable
final class ReferenceAssist {
    private(set) var suggestions: [ConditionMatch] = []
    private(set) var drugs: [DrugMatch] = []
    private(set) var topics: [HealthTopic] = []

    /// Set by the view from `@Environment(\.reference)`. Until then lookups find nothing, rather
    /// than answering from anything but the real services.
    var reference: ReferenceServices?

    /// The suggestion the student just tapped, so filling the field doesn't reopen the list.
    private var picked: String?
    /// What the current suggestions were found for.
    private var query = ""

    private enum DEBOUNCE {
        static let diagnosis: Duration = .milliseconds(250)
        static let plan: Duration = .milliseconds(400)
    }

    func diagnosisChanged(_ text: String) async {
        guard text != picked else { return }
        picked = nil
        try? await Task.sleep(for: DEBOUNCE.diagnosis)
        guard !Task.isCancelled else { return }
        let found = (try? await reference?.conditions.search(text, limit: 4)) ?? []
        guard !Task.isCancelled else { return }
        query = text
        // Hide the list once the field already says exactly the top match.
        suggestions = found.first?.name.caseInsensitiveCompare(text) == .orderedSame ? [] : found
    }

    /// Why a suggestion matched when its name doesn't show it ("PE"), or nil.
    func hint(for match: ConditionMatch) -> String? {
        ReferenceMatching.matchedSynonym(query, in: match)
    }

    func pick(_ match: ConditionMatch) -> String {
        picked = match.name
        suggestions = []
        return match.name
    }

    func dismissSuggestions() { suggestions = [] }

    func planChanged(_ text: String) async {
        try? await Task.sleep(for: DEBOUNCE.plan)
        guard !Task.isCancelled else { return }
        let found = (try? await reference?.drugs.recognize(in: text)) ?? []
        guard !Task.isCancelled else { return }
        drugs = found
    }

    func loadTopics(for diagnosis: String) async {
        topics = (try? await reference?.topics.topics(for: diagnosis)) ?? []
    }
}
