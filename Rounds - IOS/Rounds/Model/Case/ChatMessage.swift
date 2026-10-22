import SwiftUI
import Observation

struct ChatMessage: Identifiable, Equatable {
    enum Kind: Equatable { case doctor, patient, reveal, problem }
    let id = UUID()
    let kind: Kind
    /// Grows while a streamed patient reply is being written, then settles on the finished one.
    var text: String
}
