// LiveFace.swift: drawing a living face (eyes that slide and blink, a mouth that opens), from the
// rossark motion method. Choreo holds the tracks; EyeGeometry and FaceInk the shapes and colors.
import SwiftUI

/// A rounded pill (stadium) centred on (cx, cy).
func pill(cx: CGFloat, cy: CGFloat, w: CGFloat, h: CGFloat) -> Path {
    Path(roundedRect: CGRect(x: cx - w / 2, y: cy - h / 2, width: w, height: h), cornerRadius: min(w, h) / 2)
}

// MARK: - The live eye

/// Draws one living eye into `context`, which must already be in the head's coordinates.
/// The pupil and shine slide, clipped to the white. The lid and cheek are skin clipped to a
/// pill 2 units LARGER than the white: clipped to the exact white, the anti-aliased edge leaks
/// around a closed eye and reads as glasses. `side`: -1 the eye on the viewer's left, 1 the right.
func drawLiveEye(
    _ context: GraphicsContext, side: CGFloat, eye: EyeGeometry, ink: FaceInk, choreo: Choreo, t: Double
) {
    drawLiveEye(context, side: side, eye: eye, ink: ink,
                lid: CGFloat(track(t, side > 0 ? (choreo.lidRight ?? choreo.lid) : choreo.lid)),
                lookX: CGFloat(track(t, choreo.lookX)), lookY: CGFloat(track(t, choreo.lookY)),
                cheek: choreo.cheek.map { CGFloat(track(t, $0)) })
}

/// The same eye from values already worked out, for a scene that layers its own motion on top
/// (follow-through, gaze that follows a prop) instead of reading one `Choreo`.
func drawLiveEye(
    _ context: GraphicsContext, side: CGFloat, eye: EyeGeometry, ink: FaceInk,
    lid: CGFloat, lookX lx: CGFloat, lookY ly: CGFloat, cheek: CGFloat? = nil
) {
    let cx = eye.cx, cy = eye.cy, w = eye.w, h = eye.h
    let top = cy - h / 2 + eye.pupilTop + ly
    let lidH = h + 4

    // The pupil and its shine, inside the white.
    context.drawLayer { c in
        c.clip(to: pill(cx: cx, cy: cy, w: w, h: h))
        let pupil = CGRect(x: cx + lx - eye.pupilW / 2, y: top, width: eye.pupilW, height: eye.pupilH)
        c.fill(Path(roundedRect: pupil, cornerRadius: eye.pupilW / 2), with: .color(ink.pupil))
        if eye.shine > 0 {
            let s = CGPoint(x: cx + lx - eye.pupilW * 0.22, y: top + eye.shine + 1.6)
            c.fill(Path(ellipseIn: CGRect(x: s.x - eye.shine, y: s.y - eye.shine, width: eye.shine * 2, height: eye.shine * 2)),
                   with: .color(ink.white))
        }
    }

    // The skin that slides over it: the lid from the top, the cheek from the bottom.
    context.drawLayer { c in
        c.clip(to: pill(cx: cx, cy: cy, w: w + 2, h: h + 2))
        c.fill(Path(CGRect(x: cx - w / 2 - 2, y: cy - h / 2 - 2, width: w + 4, height: lid * lidH)), with: .color(ink.skin))
        // The lid's edge: shows as soon as it starts down, hides when the closed line takes over.
        let lashOn = min(1, lid / 0.06) * min(1, max(0, (0.95 - lid) / 0.08))
        if lashOn > 0 {
            let y = cy - h / 2 - 2 + lid * lidH
            var lash = Path()
            lash.move(to: CGPoint(x: cx - w / 2 - 2, y: y))
            lash.addLine(to: CGPoint(x: cx + w / 2 + 2, y: y))
            c.stroke(lash, with: .color(ink.line.opacity(lashOn)), lineWidth: ink.lineWidth * 0.6)
        }
        if let k = cheek {
            c.fill(Path(CGRect(x: cx - w / 2 - 2, y: cy + h / 2 + 2 - k * lidH, width: w + 4, height: k * lidH)),
                   with: .color(ink.skin))
        }
    }

    // The closed eye: a line with the outer tip dropping, once the lid is nearly down.
    let closedOn = min(1, max(0, (lid - 0.88) / 0.12))
    if closedOn > 0 {
        var closed = Path()
        closed.move(to: CGPoint(x: cx - side * w * 0.37, y: cy))
        closed.addLine(to: CGPoint(x: cx + side * w * 0.13, y: cy))
        closed.addQuadCurve(to: CGPoint(x: cx + side * w * 0.37, y: cy + h * 0.17),
                            control: CGPoint(x: cx + side * w * 0.33, y: cy))
        context.stroke(closed, with: .color(ink.line.opacity(closedOn)),
                       style: StrokeStyle(lineWidth: ink.lineWidth, lineCap: .round, lineJoin: .round))
    }

    // The happy squint: an upward arc once the cheek is nearly up.
    if let k = cheek {
        let happyOn = min(1, max(0, (k - 0.86) / 0.14))
        if happyOn > 0 {
            var arc = Path()
            arc.move(to: CGPoint(x: cx - w * 0.4, y: cy - h * 0.1))
            arc.addQuadCurve(to: CGPoint(x: cx + w * 0.4, y: cy - h * 0.1), control: CGPoint(x: cx, y: cy - h * 0.7))
            context.stroke(arc, with: .color(ink.line.opacity(happyOn)),
                           style: StrokeStyle(lineWidth: ink.lineWidth, lineCap: .round))
        }
    }
}

// MARK: - The live mouth

/// Draws a living open mouth: the dark inside deepens and shallows, the tongue follows.
/// `x0`/`x1` are the corners, `top` the upper lip line, `tilt` how much higher the right
/// corner sits. It never fully closes: with the teeth on top it reads as talking.
func drawLiveMouth(
    _ context: GraphicsContext, x0: CGFloat, x1: CGFloat, top: CGFloat, tilt: CGFloat = 0,
    mouth: Color, tongue: Color, teeth: Color? = nil, choreo: Choreo, t: Double, restDepth: CGFloat = 11
) {
    let d = choreo.mouth.map { CGFloat(track(t, $0)) } ?? restDepth
    let mid = (x0 + x1) / 2
    var dark = Path()
    dark.move(to: CGPoint(x: x0, y: top))
    dark.addLine(to: CGPoint(x: x1, y: top - tilt))
    dark.addQuadCurve(to: CGPoint(x: mid, y: top + d), control: CGPoint(x: x1 + 2, y: top + d))
    dark.addQuadCurve(to: CGPoint(x: x0, y: top), control: CGPoint(x: x0 - 2, y: top + d))
    dark.closeSubpath()
    context.fill(dark, with: .color(mouth))
    let r = min(d * 0.36, (x1 - x0) * 0.22)
    let ty = top + d - r - 1.5
    context.fill(Path(ellipseIn: CGRect(x: mid + 1 - r, y: ty - r, width: r * 2, height: r * 2)), with: .color(tongue))
    if let teeth {
        var tooth = Path()
        tooth.move(to: CGPoint(x: x0 + 1, y: top))
        tooth.addLine(to: CGPoint(x: x1 - 1, y: top - tilt))
        tooth.addLine(to: CGPoint(x: x1 - 1.5, y: top - tilt + 5))
        tooth.addLine(to: CGPoint(x: x0 + 1.5, y: top + 5))
        tooth.closeSubpath()
        context.fill(tooth, with: .color(teeth))
    }
}
