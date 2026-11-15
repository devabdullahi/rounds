import CoreGraphics

/// Zoom and pan of a scan in the reading room. Pure value math so the limits are testable:
/// the image never shrinks below fit, never zooms past `maxScale`, and can't be dragged off screen.
struct ScanZoom: Equatable, Sendable {
    static let maxScale: CGFloat = 5
    /// Double-tap zooms here from fit, and back to fit from anywhere else.
    static let doubleTapScale: CGFloat = 2.5

    var scale: CGFloat = 1
    var offset: CGSize = .zero

    var isFit: Bool { scale <= 1.001 && offset == .zero }

    /// The scale after a pinch of `magnification` from `base`, kept between fit and `maxScale`.
    static func scale(_ base: CGFloat, pinched magnification: CGFloat) -> CGFloat {
        min(max(base * magnification, 1), maxScale)
    }

    /// The size `image` takes when fitted into `frame` (aspect kept, so one axis may letterbox).
    static func fitted(_ image: CGSize, in frame: CGSize) -> CGSize {
        guard image.width > 0, image.height > 0 else { return frame }
        let ratio = min(frame.width / image.width, frame.height / image.height)
        return CGSize(width: image.width * ratio, height: image.height * ratio)
    }

    /// Keeps the zoomed film on screen: an axis pans only by how far the scaled film overflows the
    /// frame on that axis, so a letterboxed film can't be dragged into its own empty band.
    static func clamp(_ offset: CGSize, scale: CGFloat, film: CGSize, in frame: CGSize) -> CGSize {
        let maxX = max(0, (film.width * scale - frame.width) / 2)
        let maxY = max(0, (film.height * scale - frame.height) / 2)
        return CGSize(width: min(max(offset.width, -maxX), maxX),
                      height: min(max(offset.height, -maxY), maxY))
    }

    /// Double-tap: fit → zoomed in, anything else → fit.
    func toggled() -> ScanZoom {
        isFit ? ScanZoom(scale: Self.doubleTapScale, offset: .zero) : ScanZoom()
    }
}
