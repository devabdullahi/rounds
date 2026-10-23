import SwiftUI
import Observation

struct Feedback: Identifiable {
    enum Tone { case good, miss }
    let id = UUID()
    let tone: Tone
    let title: String
    let detail: String
    var coversMiss: String? = nil   // a Miss flag this note already explains
    /// About an area the student said they find hardest; the debrief marks it.
    var isFocus = false
}
