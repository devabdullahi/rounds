import SwiftUI

/// A doctor drawn without a face, hair or skin tone, so it fits anyone: head and shoulders in
/// the accent color, a white coat's lapels and a stethoscope. Used as the photo on the welcome badge.
struct DoctorAvatar: View {
    var size: CGFloat = 84

    var body: some View {
        Canvas { ctx, s in
            let u = s.width / 84
            func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * u, y: y * u) }
            ctx.fill(Path(ellipseIn: CGRect(origin: .zero, size: s)), with: .color(Theme.accentSoft))
            // Shoulders, in a white coat.
            var coat = Path()
            coat.move(to: p(12, 84)); coat.addCurve(to: p(42, 54), control1: p(13, 64), control2: p(28, 54))
            coat.addCurve(to: p(72, 84), control1: p(56, 54), control2: p(71, 64)); coat.closeSubpath()
            ctx.fill(coat, with: .color(Theme.surface))
            ctx.stroke(coat, with: .color(Theme.accent.opacity(0.35)), lineWidth: 1.5 * u)
            // Scrubs in the V of the coat.
            var scrubs = Path()
            scrubs.move(to: p(34, 56)); scrubs.addLine(to: p(42, 72)); scrubs.addLine(to: p(50, 56)); scrubs.closeSubpath()
            ctx.fill(scrubs, with: .color(Theme.accent))
            // Head and neck, one flat tone.
            ctx.fill(Path(CGRect(x: 37 * u, y: 44 * u, width: 10 * u, height: 12 * u)), with: .color(Theme.accentText))
            ctx.fill(Path(ellipseIn: CGRect(x: 28 * u, y: 18 * u, width: 28 * u, height: 30 * u)), with: .color(Theme.accentText))
            // Stethoscope around the neck.
            var steth = Path()
            steth.move(to: p(31, 58)); steth.addQuadCurve(to: p(36, 76), control: p(28, 70))
            steth.move(to: p(53, 58)); steth.addQuadCurve(to: p(54, 72), control: p(57, 66))
            ctx.stroke(steth, with: .color(Theme.text.opacity(0.7)), style: StrokeStyle(lineWidth: 2 * u, lineCap: .round))
            ctx.fill(Path(ellipseIn: CGRect(x: 50.5 * u, y: 71 * u, width: 7 * u, height: 7 * u)), with: .color(Theme.text.opacity(0.7)))
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .accessibilityHidden(true)
    }
}
