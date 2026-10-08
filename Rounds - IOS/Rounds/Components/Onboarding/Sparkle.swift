import SwiftUI

/// Four-point sparkle, the hero art's accent mark.
struct Sparkle: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        let c = CGPoint(x: r.midX, y: r.midY)
        p.move(to: CGPoint(x: c.x, y: r.minY))
        p.addQuadCurve(to: CGPoint(x: r.maxX, y: c.y), control: CGPoint(x: c.x + r.width * 0.06, y: c.y - r.height * 0.06))
        p.addQuadCurve(to: CGPoint(x: c.x, y: r.maxY), control: CGPoint(x: c.x + r.width * 0.06, y: c.y + r.height * 0.06))
        p.addQuadCurve(to: CGPoint(x: r.minX, y: c.y), control: CGPoint(x: c.x - r.width * 0.06, y: c.y + r.height * 0.06))
        p.addQuadCurve(to: CGPoint(x: c.x, y: r.minY), control: CGPoint(x: c.x - r.width * 0.06, y: c.y - r.height * 0.06))
        return p
    }
}
