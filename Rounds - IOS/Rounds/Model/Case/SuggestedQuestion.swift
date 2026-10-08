import Foundation

/// A one-tap prompt; hidden once its fact is revealed, however it was asked.
struct SuggestedQuestion: Hashable {
    let text: String
    let fact: String
}
