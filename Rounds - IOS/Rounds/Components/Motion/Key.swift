import Foundation

/// A keyframe: time (ms), value, and whether the segment ARRIVING here eases out (default: ease-in-out).
struct Key: Sendable {
    let ms: Double
    let value: Double
    let easeOut: Bool
    init(_ ms: Double, _ value: Double, out easeOut: Bool = false) {
        self.ms = ms
        self.value = value
        self.easeOut = easeOut
    }
}

typealias Keys = [Key]
