import Foundation

/// A result the server returned for an ordered test.
struct TestResult: Hashable {
    let text: String
    let isAbnormal: Bool
}
