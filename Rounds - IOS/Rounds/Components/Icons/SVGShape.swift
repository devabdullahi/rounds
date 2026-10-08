import SwiftUI

/// Draws an SVG path string as a SwiftUI shape. Used for animated line art (the ECG traces),
/// which needs real geometry to trim and sweep. Icons are image assets, not paths: see Icons.swift.
struct SVGShape: Shape {
    let d: String
    let viewBox: CGSize
    func path(in rect: CGRect) -> Path {
        var p = Path()
        SVGPath.append(d, to: &p)
        return p.applying(CGAffineTransform(translationX: rect.minX, y: rect.minY)
            .scaledBy(x: rect.width / viewBox.width, y: rect.height / viewBox.height))
    }
}
