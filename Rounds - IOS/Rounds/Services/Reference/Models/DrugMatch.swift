import Foundation

/// A drug recognised in free text, normalised to its RxNorm concept.
struct DrugMatch: Identifiable, Hashable, Sendable {
    let rxcui: String
    let name: String            // normalised name, e.g. "Aspirin"
    let matchedText: String     // what the student actually typed, e.g. "ASA"
    var id: String { rxcui }
}
