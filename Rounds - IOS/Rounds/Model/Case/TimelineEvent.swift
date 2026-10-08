import SwiftUI
import Observation

/// One thing the student did, for the handoff timeline.
struct TimelineEvent: Identifiable {
    enum Kind { case question, exam, test }
    let id = UUID()
    let at: Date
    let kind: Kind
    let text: String
}
