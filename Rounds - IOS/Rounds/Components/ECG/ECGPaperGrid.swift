import SwiftUI

/// Chart-paper grid: minor every 4pt (1 mm), heavier every 5th line (5 mm).
struct ECGPaperGrid: View {
    var minor: CGFloat = 4
    var body: some View {
        Canvas { ctx, size in
            var minorPath = Path(), majorPath = Path()
            var i = 0
            var x: CGFloat = 0
            while x <= size.width {
                var p = Path(); p.move(to: CGPoint(x: x, y: 0)); p.addLine(to: CGPoint(x: x, y: size.height))
                i % 5 == 0 ? majorPath.addPath(p) : minorPath.addPath(p)
                x += minor; i += 1
            }
            i = 0
            var y = size.height
            while y >= 0 {   // anchor to the bottom so the baseline sits on a major line
                var p = Path(); p.move(to: CGPoint(x: 0, y: y)); p.addLine(to: CGPoint(x: size.width, y: y))
                i % 5 == 0 ? majorPath.addPath(p) : minorPath.addPath(p)
                y -= minor; i += 1
            }
            ctx.stroke(minorPath, with: .color(Theme.ecgGridMinor), lineWidth: 0.5)
            ctx.stroke(majorPath, with: .color(Theme.ecgGridMajor), lineWidth: 0.8)
        }
        .accessibilityHidden(true)
    }
}
