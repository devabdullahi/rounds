import SwiftUI

/// Circle whose edge is displaced by a few sine harmonics: alive, but still clearly a circle.
struct BlobShape: Shape {
    var phase: Double
    var amplitude: CGFloat

    var animatableData: CGFloat {
        get { amplitude }
        set { amplitude = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let r = min(rect.width, rect.height) / 2 * (1 - amplitude)   // keep the wobble inside the frame
        let steps = 96
        var p = Path()
        for i in 0...steps {
            let θ = Double(i) / Double(steps) * 2 * .pi
            let n = 0.5 * sin(3 * θ + phase) + 0.3 * sin(5 * θ - 1.3 * phase) + 0.2 * sin(2 * θ + 0.7 * phase)
            let rr = r * (1 + amplitude * CGFloat(n))
            let pt = CGPoint(x: c.x + rr * CGFloat(cos(θ)), y: c.y + rr * CGFloat(sin(θ)))
            i == 0 ? p.move(to: pt) : p.addLine(to: pt)
        }
        p.closeSubpath()
        return p
    }
}
