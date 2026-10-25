import SwiftUI

/// A young doctor for onboarding scenes: white coat over scrubs, a stethoscope around the neck,
/// a pen in the pocket, and one flat tone for the head so anyone can see themselves in it. The eyes
/// are live (`drawLiveEye`): pupils slide, lids blink, cheeks lift into a happy squint.
enum DoctorFigure {
    /// Draws the figure centered on `center`, `size` points wide, in `tone`.
    static func draw(_ g: GraphicsContext, center: CGPoint, size: CGFloat, tone: Color, pose: FigurePose) {
        let k = size / 100
        g.drawLayer { c in
            c.translateBy(x: center.x - 50 * k + pose.dx, y: center.y - 50 * k - pose.breath)
            c.scaleBy(x: k, y: k)
            body(c, tone: tone)
            c.drawLayer { head in
                head.translateBy(x: 50, y: 64); head.rotate(by: .degrees(pose.tilt)); head.translateBy(x: -50, y: -64)
                face(head, tone: tone, pose: pose)
            }
        }
    }

    private static func body(_ c: GraphicsContext, tone: Color) {
        let F = Theme.Figure.self
        var coat = Path()
        coat.move(to: CGPoint(x: 10, y: 100))
        coat.addCurve(to: CGPoint(x: 50, y: 66), control1: CGPoint(x: 11, y: 78), control2: CGPoint(x: 29, y: 66))
        coat.addCurve(to: CGPoint(x: 90, y: 100), control1: CGPoint(x: 71, y: 66), control2: CGPoint(x: 89, y: 78))
        coat.closeSubpath()
        c.fill(coat, with: .color(F.coat))
        c.stroke(coat, with: .color(F.coatLine), lineWidth: 1.5)
        c.fill(polygon([(41, 67), (50, 84), (59, 67)]), with: .color(F.scrubs))
        var lapels = Path()
        lapels.addLines([CGPoint(x: 41, y: 67), CGPoint(x: 47, y: 86), CGPoint(x: 45, y: 100)])
        lapels.addLines([CGPoint(x: 59, y: 67), CGPoint(x: 53, y: 86), CGPoint(x: 55, y: 100)])
        c.stroke(lapels, with: .color(F.coatLine), style: StrokeStyle(lineWidth: 1.4, lineJoin: .round))
        c.stroke(polygon([(66, 86), (76, 86), (75.5, 95), (66.5, 95)]), with: .color(F.coatLine), lineWidth: 1.2)
        c.stroke(line((70, 82), (70, 88)), with: .color(F.scrubs), style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
        c.fill(Path(CGRect(x: 45, y: 56, width: 10, height: 12)), with: .color(tone))
        // The stethoscope: tubing down both sides of the collar, the chest piece hanging on one.
        var tube = Path()
        tube.move(to: CGPoint(x: 43, y: 66))
        tube.addCurve(to: CGPoint(x: 37, y: 93), control1: CGPoint(x: 35, y: 72), control2: CGPoint(x: 33, y: 84))
        tube.move(to: CGPoint(x: 57, y: 66))
        tube.addCurve(to: CGPoint(x: 64, y: 88), control1: CGPoint(x: 64, y: 71), control2: CGPoint(x: 67, y: 79))
        tube.move(to: CGPoint(x: 43, y: 66))
        tube.addQuadCurve(to: CGPoint(x: 57, y: 66), control: CGPoint(x: 50, y: 70))
        c.stroke(tube, with: .color(F.stethoscope), style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
        c.fill(circle(64, 91, 3.6), with: .color(F.stethoscope))
        c.fill(circle(64, 91, 1.6), with: .color(F.bellFace))
        c.fill(circle(37, 94.5, 1.6), with: .color(F.stethoscope))
    }

    private static func face(_ c: GraphicsContext, tone: Color, pose: FigurePose) {
        let F = Theme.Figure.self
        c.fill(Path(ellipseIn: CGRect(x: 26, y: 13, width: 48, height: 50)), with: .color(tone))
        let ink = FaceInk(white: F.eyeWhite, pupil: F.ink, skin: tone, line: F.ink, lineWidth: 1.6)
        for (side, cx) in [(CGFloat(-1), CGFloat(41.5)), (1, 58.5)] {
            let eye = EyeGeometry(cx: cx, cy: 38, w: 8.5, h: 11.5, pupilW: 5, pupilH: 6.5, pupilTop: 2.4, shine: 1)
            drawLiveEye(c, side: side, eye: eye, ink: ink, lid: pose.lid, lookX: pose.lookX, lookY: pose.lookY, cheek: pose.cheek)
        }
        let s = pose.smile * 5
        var mouth = Path()
        mouth.move(to: CGPoint(x: 44.5, y: 51 - s * 0.15))
        mouth.addQuadCurve(to: CGPoint(x: 55.5, y: 51 - s * 0.15), control: CGPoint(x: 50, y: 51 + s))
        c.stroke(mouth, with: .color(F.ink), style: StrokeStyle(lineWidth: 1.8, lineCap: .round))
    }

    private static func circle(_ x: CGFloat, _ y: CGFloat, _ r: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
    }

    private static func polygon(_ points: [(CGFloat, CGFloat)]) -> Path {
        var p = Path()
        p.addLines(points.map { CGPoint(x: $0.0, y: $0.1) })
        p.closeSubpath()
        return p
    }

    private static func line(_ a: (CGFloat, CGFloat), _ b: (CGFloat, CGFloat)) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: a.0, y: a.1)); p.addLine(to: CGPoint(x: b.0, y: b.1))
        return p
    }
}
