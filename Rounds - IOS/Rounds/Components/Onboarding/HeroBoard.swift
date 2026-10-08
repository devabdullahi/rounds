import SwiftUI

/// The fixed 350×400 board (the design's frame) hero art is laid out on, and how it scales
/// into the space a screen gives it, so every element keeps its place on any phone.
enum HeroBoard {
    static let size = CGSize(width: 350, height: 400)
    /// Never blown up past 115%, or the art outgrows the headline on large phones.
    static let maxScale: CGFloat = 1.15

    static func scale(in space: CGSize) -> CGFloat {
        min(space.width / size.width, space.height / size.height, maxScale)
    }

    /// Top-left corner of the scaled board, centred in `space`.
    static func origin(in space: CGSize) -> CGPoint {
        let s = scale(in: space)
        return CGPoint(x: (space.width - size.width * s) / 2, y: (space.height - size.height * s) / 2)
    }
}
