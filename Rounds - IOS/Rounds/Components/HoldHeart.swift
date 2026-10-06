import SwiftUI

/// A heart that fills with red from the bottom as `progress` goes 0 → 1. Drawing only; the
/// hold rule lives in `HoldToCommit` and the gesture in the screen that owns it.
struct HoldHeart: View {
    let progress: Double
    var size: CGFloat = 220

    /// Phosphor "heart" (fill), 256×256.
    private static let heart = SVGShape(
        d: "M178 40c-20.65 0-38.73 8.88-50 23.89C116.73 48.88 98.65 40 78 40a62.07 62.07 0 0 0-62 62c0 70 103.79 126.66 108.21 129a8 8 0 0 0 7.58 0C136.21 228.66 240 172 240 102a62.07 62.07 0 0 0-62-62Z",
        viewBox: CGSize(width: 256, height: 256))

    /// The heart's drawn span inside its box, so the fill starts at its tip and ends at its top.
    private static let top: CGFloat = 40 / 256
    private static let bottom: CGFloat = 232 / 256

    var body: some View {
        let fillTop = Self.bottom - (Self.bottom - Self.top) * progress
        ZStack {
            Self.heart.fill(Theme.surface)
            Self.heart.fill(Theme.wrong)
                .mask(alignment: .bottom) {
                    Rectangle().frame(height: size * (1 - fillTop))
                }
            Self.heart.stroke(Theme.wrong, style: StrokeStyle(lineWidth: size * 8 / 256, lineJoin: .round))
        }
        .frame(width: size, height: size)
        .shadow(color: Theme.wrong.opacity(0.22), radius: 18, y: 18)
    }
}
