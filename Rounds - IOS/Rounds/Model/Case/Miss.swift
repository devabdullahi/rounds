import Foundation

/// A red flag or step skipped on a specific patient, with the reason it matters.
struct Miss: Identifiable, Hashable {
    var id: String { flag }
    let flag: String
    let why: String
}
