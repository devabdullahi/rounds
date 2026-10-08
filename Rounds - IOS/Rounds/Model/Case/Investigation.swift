import Foundation

/// An orderable test. Its result arrives from the server when ordered.
struct Investigation: Identifiable, Hashable {
    let id: String
    let name: String
    let detail: String
    let cost: Int
    let turnaround: Double     // seconds until result in-app
    var delaysCareMinutes = 0  // time added before definitive treatment
}
