import Foundation

/// A result the server returned for an ordered test.
struct TestResult: Hashable {
    let text: String
    let isAbnormal: Bool
    /// The real image behind an imaging result; nil for lab and text-only results.
    var scan: ScanImage? = nil
}
