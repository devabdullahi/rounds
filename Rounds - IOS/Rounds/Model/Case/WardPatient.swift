import Foundation

/// A patient on the student's ward: one generated case and how it went so far.
struct WardPatient: Identifiable, Hashable {
    let id: String              // bed, e.g. "C42"
    let quote: String
    let meta: String            // "F · 78 · Family medicine"
    let rotation: Clerkship?
    let system: OrganSystem?
    let hr: Int?
    let bp: String?
    let spo2: Int?
    var status: Status
    /// Red flags missed on the latest graded attempt, and its score.
    var misses: [Miss] = []
    var lastScore: Int?

    enum Status: Hashable { case new, resume, revisit, done }

    func fits(_ focus: FocusSelection) -> Bool {
        focus.isMix || focus.items.contains { item in
            switch item {
            case .mix: true
            case .rotation(let c): c == rotation
            case .system(let s): s == system
            }
        }
    }
}
