import SwiftUI
import Observation

struct ChatMessage: Identifiable, Equatable {
    enum Kind: Equatable { case doctor, patient, reveal, problem }
    let id = UUID()
    let kind: Kind
    let text: String
}
