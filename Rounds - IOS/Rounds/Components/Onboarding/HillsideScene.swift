import SwiftUI

/* ─────────────────────────────────────────────────────────
 * ANIMATION STORYBOARD · Welcome hillside
 *
 *    0ms   sky fades in (800ms); the sun's halo breathes (5s loop)
 *  100ms   hills rise back to front, y 70 → 0 (900ms, ease-out), 120ms apart
 *  450ms   hospital grows in from its base, 0.7 → 1 (800ms); windows light one by one from 700ms
 *  700ms   the path draws up to the entrance (1000ms)
 *  800ms   tree, bench and patient grow in; the ambulance rolls in from the left
 * 1000ms   the student walks in from the right
 * 1600ms   conversation loop (4s): the student asks, gesturing; the patient answers, pointing
 *  loop    clouds drift, birds glide, the tree sways, both breathe, a visitor walks up the
 *          path, the sign's cross beats, one window flickers, the siren blinks
 * Reduce Motion: the final scene, still, with both speech bubbles showing.
 * ───────────────────────────────────────────────────────── */

private enum TIMING {
    static let hills: [Double] = [100, 220, 340, 460]
    static let hillRise = 900.0
    static let hospital = 450.0
    static let windows = 700.0
    static let path = 700.0
    static let scene = 800.0
    static let student = 1000.0
    static let talk = 1600.0
    /// Past this every intro beat has landed: Reduce Motion draws this moment.
    static let settled = 2400.0
}

private enum TALK {
    static let period = 4000.0
    static let ask: Keys = [Key(0, 0), Key(160, 0), Key(400, 1, out: true), Key(1760, 1), Key(2000, 0), Key(4000, 0)]
    static let answer: Keys = [Key(0, 0), Key(1920, 0), Key(2160, 1, out: true), Key(3680, 1), Key(3920, 0), Key(4000, 0)]
    static let studentArm: Keys = [Key(0, 0), Key(320, 0), Key(560, -38, out: true), Key(1600, -38), Key(1840, 0), Key(4000, 0)]
    static let patientArm: Keys = [Key(0, 0), Key(2080, 0), Key(2320, 28, out: true), Key(3520, 28), Key(3760, 0), Key(4000, 0)]
}

/// The welcome screen's living scene: a hospital on a hillside, where a medical student in a
/// white coat asks a patient on a bench "Where's the pain?" and hears "Right here, doc". Drawn in
/// the design's 390 × 844 space, scaled to the screen's width and pinned to the bottom.
struct HillsideScene: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var start = Date()

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { ctx in
            let t = reduceMotion ? TIMING.settled : ctx.date.timeIntervalSince(start) * 1000
            Canvas { gc, size in
                let k = size.width / 390
                gc.fill(Path(CGRect(origin: .zero, size: size)),
                        with: .linearGradient(Gradient(colors: [Theme.Hillside.skyTop, Theme.Hillside.skyBottom]),
                                              startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)))
                var g = gc
                g.translateBy(x: 0, y: size.height - 844 * k)
                g.scaleBy(x: k, y: k)
                draw(g, t: t)
            }
        }
        .ignoresSafeArea()
        .onAppear { start = .now }
        .accessibilityHidden(true)
    }

    // MARK: Scene

    private func draw(_ g: GraphicsContext, t: Double) {
        let H = Theme.Hillside.self
        let loopT = max(0, t - TIMING.talk)
        let still = reduceMotion

        // Sky: the sun and its breathing halo, clouds, birds.
        let halo = still ? 0 : (wave(t, period: 5000) + 1) / 2
        g.drawLayer { c in
            c.opacity = 0.5 - 0.25 * halo
            scaled(&c, 1 + 0.12 * halo, at: CGPoint(x: 318, y: 292))
            c.fill(circle(318, 292, 74), with: .color(H.white))
        }
        g.fill(circle(318, 292, 44), with: .color(H.sun))
        layer(g, dx: still ? 0 : 20 * wave(t, period: 28000), opacity: 0.9) { c in
            for (x, y, rx, ry) in [(70.0, 300.0, 34.0, 13.0), (92, 292, 22, 14), (52, 294, 16, 10)] { c.fill(ellipse(x, y, rx, ry), with: .color(H.white)) }
        }
        if !still {
            layer(g, dx: -120 + 580 * loop(t, period: 26000), opacity: 0.8) { c in
                c.fill(ellipse(0, 236, 30, 10), with: .color(H.white)); c.fill(ellipse(18, 229, 18, 11), with: .color(H.white))
            }
        }
        layer(g, dx: still ? 0 : -20 * wave(t, period: 36000), opacity: 0.75) { c in
            c.fill(ellipse(220, 340, 26, 9), with: .color(H.white)); c.fill(ellipse(236, 334, 16, 10), with: .color(H.white))
        }
        for (i, (d, w)) in [("M150 268q5-5 10 0q5-5 10 0", 2.0), ("M178 284q4-4 8 0q4-4 8 0", 1.6)].enumerated() {
            let gl = still ? 0 : (wave(t, period: 6000, phase: Double(i) / 3) + 1) / 2
            layer(g, dx: 18 * gl, dy: -6 * gl) { c in
                c.stroke(svg(d), with: .color(H.bird), style: StrokeStyle(lineWidth: w, lineCap: .round))
            }
        }

        // Back hill, then the hospital on it.
        hill(g, "M0 470 C 70 430, 150 452, 220 420 C 290 390, 340 404, 390 392 V900 H0 Z", H.hill1, t, 0)
        hospital(g, t: t)

        hill(g, "M0 540 C 80 500, 170 524, 240 514 C 310 504, 350 512, 390 500 V900 H0 Z", H.hill2, t, 1)
        let drawn = seg(t, TIMING.path, TIMING.path + 1000)
        g.stroke(svg("M196 844 C 186 720, 214 620, 240 524").trimmedPath(from: 0, to: drawn),
                 with: .color(H.path), style: StrokeStyle(lineWidth: 30, lineCap: .round))
        if !still { visitor(g, t: t) }
        ambulance(g, t: t)

        hill(g, "M0 610 C 90 576, 170 604, 260 572 C 320 552, 362 562, 390 556 V900 H0 Z", H.hill3, t, 2)
        bench(g, t: t, loopT: loopT)
        student(g, t: t, loopT: loopT)
        speech(g, t: t, loopT: loopT)

        hill(g, "M0 690 C 110 662, 220 684, 390 652 V900 H0 Z", H.hill4, t, 3)
        g.fill(svg("M20 704l4-12 4 12zM34 700l3-9 3 9zM330 676l4-12 4 12zM346 674l3-9 3 9zM256 690l3-9 3 9z"), with: .color(H.grass))
        for (x, y, r) in [(300.0, 690.0, 3.0), (60, 712, 2.5), (370, 680, 2.5)] { g.fill(circle(x, y, r), with: .color(H.flower)) }
    }

    private func hill(_ g: GraphicsContext, _ d: String, _ color: Color, _ t: Double, _ i: Int) {
        let rise = seg(t, TIMING.hills[i], TIMING.hills[i] + TIMING.hillRise)
        layer(g, dy: 70 * (1 - rise)) { c in c.fill(svg(d), with: .color(color)) }
    }

    private func hospital(_ g: GraphicsContext, t: Double) {
        let H = Theme.Hillside.self
        let grow = seg(t, TIMING.hospital, TIMING.hospital + 800)
        g.drawLayer { c in
            c.opacity = grow
            scaled(&c, 0.7 + 0.3 * grow, at: CGPoint(x: 260, y: 524))
            c.fill(rounded(168, 386, 140, 138, 6), with: .color(H.white))
            c.fill(rounded(168, 386, 140, 16, 6), with: .color(H.roof))
            c.fill(rounded(300, 430, 52, 94, 4), with: .color(H.wing))
            c.fill(rounded(300, 430, 52, 10, 4), with: .color(H.roofDark))
            c.stroke(circle(326, 452, 9), with: .color(H.wingRule), lineWidth: 2)
            c.stroke(svg("M322 448v8M330 448v8M322 452h8"), with: .color(H.wingCross), lineWidth: 2)
            c.fill(rounded(216, 352, 44, 34, 6), with: .color(H.white))
            c.stroke(rounded(216, 352, 44, 34, 6), with: .color(H.signEdge), lineWidth: 2)
            // The sign's cross beats like a heart once the scene has settled.
            let beatP = loop(max(0, t - TIMING.talk), period: 2400)
            let beat = reduceMotion ? 1 : flow(beatP * 2400, [(0, 1), (240, 1.12), (480, 0.97), (720, 1), (2400, 1)])
            c.drawLayer { s in
                scaled(&s, beat, at: CGPoint(x: 238, y: 369))
                s.stroke(svg("M238 359v20M228 369h20"), with: .color(H.siren), style: StrokeStyle(lineWidth: 6, lineCap: .round))
            }
            // Windows light up one by one; one of them flickers now and then.
            let windows: [(CGFloat, CGFloat, Double?)] = [
                (182, 414, 0), (212, 414, 2), (244, 414, 4), (274, 414, 1), (182, 442, 3), (212, 442, -1),
                (244, 442, nil), (274, 442, 0), (182, 470, nil), (274, 470, 4),
            ]
            for (x, y, order) in windows {
                var lit = 0.0
                if let order {
                    let at = TIMING.windows + (order < 0 ? 200 : order * 100)
                    lit = seg(t, at, at + 400)
                    if order < 0 && !reduceMotion {
                        let f = loop(max(0, t - 3000), period: 7000)
                        if f > 0.62 && f < 0.88 { lit = 1 - bell((f - 0.62) / 0.26) }
                    }
                }
                c.fill(rounded(x, y, 20, 18, 3), with: .color(mix(H.windowDark, H.windowLit, lit)))
            }
            c.fill(rounded(310, 470, 14, 14, 2), with: .color(H.windowSide))
            c.fill(rounded(330, 470, 14, 14, 2), with: .color(H.windowSide))
            c.fill(svg("M210 478h60l-6 10h-48z"), with: .color(H.roof))
            c.fill(rounded(224, 488, 32, 36, 3), with: .color(H.roofDark))
            c.stroke(svg("M240 488v36"), with: .color(H.door), lineWidth: 2)
        }
    }

    private func ambulance(_ g: GraphicsContext, t: Double) {
        let H = Theme.Hillside.self
        let roll = seg(t, TIMING.scene, TIMING.scene + 1000)
        g.drawLayer { c in
            c.opacity = roll
            c.translateBy(x: -120 * (1 - roll), y: 0)
            c.fill(rounded(58, 500, 70, 30, 7), with: .color(H.white))
            c.fill(svg("M128 508h14l8 10v12h-22z"), with: .color(H.white))
            c.fill(rounded(132, 511, 10, 8, 2), with: .color(H.glass))
            c.fill(Path(CGRect(x: 58, y: 514, width: 92, height: 5)), with: .color(H.roof))
            c.stroke(svg("M88 504v10M83 509h10"), with: .color(H.siren), style: StrokeStyle(lineWidth: 3, lineCap: .round))
            let blue = !reduceMotion && t > 1800 && loop(t - 1800, period: 1000) >= 0.5
            c.fill(rounded(100, 495, 12, 6, 2), with: .color(blue ? H.sirenBlue : H.siren))
            for x in [76.0, 134.0] {
                // Wheels turn with the distance rolled, so they don't skid in.
                c.fill(circle(x, 532, 7), with: .color(H.tire))
                c.fill(circle(x, 532, 3), with: .color(H.hub))
            }
        }
    }

    private func visitor(_ g: GraphicsContext, t: Double) {
        let H = Theme.Hillside.self
        let p = loop(max(0, t - 2000), period: 9000)
        let up = min(1, p / 0.8)
        let s = 1 - 0.45 * up
        let fade = p < 0.06 ? p / 0.06 : p > 0.8 ? max(0, 1 - (p - 0.8) / 0.08) : 1
        let step = -3 * (wave(t, period: 500) + 1) / 2
        g.drawLayer { c in
            c.opacity = fade
            c.translateBy(x: 38 * up, y: -150 * up + step)
            scaled(&c, s, at: CGPoint(x: 200, y: 707))
            c.fill(circle(200, 672, 6), with: .color(H.skinLight))
            c.fill(svg("M193 698c0-14 3-20 7-20s7 6 7 20z"), with: .color(H.visitor))
            c.fill(Path(CGRect(x: 195, y: 697, width: 4, height: 10)), with: .color(H.tire))
            c.fill(Path(CGRect(x: 201, y: 697, width: 4, height: 10)), with: .color(H.tire))
        }
    }

    private func bench(_ g: GraphicsContext, t: Double, loopT: Double) {
        let H = Theme.Hillside.self
        let grow = seg(t, TIMING.scene, TIMING.scene + 700)
        let breathe = reduceMotion ? 0 : (wave(t, period: 3000) + 1) / 2
        g.drawLayer { c in
            c.opacity = grow
            scaled(&c, 0.7 + 0.3 * grow, at: CGPoint(x: 100, y: 653))
            // The tree sways around its base; the leaves are its tips, so they carry the motion.
            c.drawLayer { tree in
                rotated(&tree, reduceMotion ? 0 : 2.5 * wave(t, period: 5000), at: CGPoint(x: 63, y: 630))
                tree.fill(Path(CGRect(x: 58, y: 560, width: 10, height: 70)), with: .color(H.trunk))
                tree.fill(circle(44, 552, 34), with: .color(H.grass))
                tree.fill(circle(80, 538, 30), with: .color(H.leafMid))
                tree.fill(circle(60, 520, 26), with: .color(H.leafLight))
                tree.fill(circle(72, 528, 6), with: .color(H.leafShine.opacity(0.8)))
            }
            c.fill(rounded(74, 628, 86, 7, 3), with: .color(H.benchSeat))
            c.fill(rounded(78, 612, 80, 6, 3), with: .color(H.benchBack))
            c.fill(Path(CGRect(x: 82, y: 635, width: 5, height: 18)), with: .color(H.benchLeg))
            c.fill(Path(CGRect(x: 148, y: 635, width: 5, height: 18)), with: .color(H.benchLeg))
            c.drawLayer { p in
                p.translateBy(x: 0, y: 628); p.scaleBy(x: 1, y: 1 + 0.025 * breathe); p.translateBy(x: 0, y: -628)
                p.fill(circle(110, 582, 12), with: .color(H.skinLight))
                p.fill(svg("M98 580c0-12 24-14 24 0c-3-5-20-6-24 0z"), with: .color(H.hairGrey))
                p.fill(svg("M94 628c0-26 6-36 16-36s16 10 16 36z"), with: .color(H.gown))
                p.drawLayer { arm in
                    rotated(&arm, reduceMotion ? 0 : track(loopT.truncatingRemainder(dividingBy: TALK.period), TALK.patientArm), at: CGPoint(x: 104, y: 606))
                    arm.stroke(svg("M104 606c4 6 10 8 16 6"), with: .color(H.skinLight), style: StrokeStyle(lineWidth: 5, lineCap: .round))
                }
            }
            c.fill(rounded(100, 626, 34, 9, 4), with: .color(H.trousers))
            c.fill(rounded(128, 630, 8, 22, 3), with: .color(H.trousers))
            c.fill(rounded(128, 650, 14, 5, 2), with: .color(H.tire))
        }
    }

    private func student(_ g: GraphicsContext, t: Double, loopT: Double) {
        let H = Theme.Hillside.self
        let walk = seg(t, TIMING.student, TIMING.student + 900)
        let breathe = reduceMotion ? 0 : (wave(t, period: 3000, phase: 0.3) + 1) / 2
        g.drawLayer { c in
            c.opacity = walk
            c.translateBy(x: 60 * (1 - walk), y: 0)
            c.translateBy(x: 0, y: 646); c.scaleBy(x: 1, y: 1 + 0.025 * breathe); c.translateBy(x: 0, y: -646)
            c.fill(circle(206, 568, 13), with: .color(H.skinDeep))
            c.fill(svg("M193 566c1-14 26-14 26 0c-4-6-21-6-26 0z"), with: .color(H.hairDark))
            c.fill(svg("M188 646c0-40 8-58 18-58s18 18 18 58z"), with: .color(H.white))
            c.stroke(svg("M206 590v54"), with: .color(H.coatSeam), lineWidth: 2)
            // Stethoscope around the neck, and a pen in the coat pocket.
            c.stroke(svg("M196 596c-6 14 2 26 12 24"), with: .color(H.ink), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
            c.fill(circle(208, 620, 3.5), with: .color(H.ink))
            c.fill(rounded(212, 604, 9, 12, 1.5), with: .color(H.roof))
            c.fill(Path(CGRect(x: 195, y: 646, width: 8, height: 26)), with: .color(H.scrubs))
            c.fill(Path(CGRect(x: 209, y: 646, width: 8, height: 26)), with: .color(H.scrubs))
            c.drawLayer { arm in
                rotated(&arm, reduceMotion ? 0 : track(loopT.truncatingRemainder(dividingBy: TALK.period), TALK.studentArm), at: CGPoint(x: 194, y: 598))
                arm.stroke(svg("M190 600c-8 8-12 16-10 22"), with: .color(H.white), style: StrokeStyle(lineWidth: 8, lineCap: .round))
            }
        }
    }

    private func speech(_ g: GraphicsContext, t: Double, loopT: Double) {
        let H = Theme.Hillside.self
        let lt = loopT.truncatingRemainder(dividingBy: TALK.period)
        let ask = reduceMotion ? 1 : (t < TIMING.talk ? 0 : track(lt, TALK.ask))
        let answer = reduceMotion ? 1 : (t < TIMING.talk ? 0 : track(lt, TALK.answer))
        bubble(g, amount: ask, anchor: CGPoint(x: 204, y: 552), rect: CGRect(x: 164, y: 508, width: 132, height: 34),
               tail: "M198 540l6 12 8-12z", fill: H.white, text: "Where's the pain?", ink: H.ink)
        bubble(g, amount: answer, anchor: CGPoint(x: 106, y: 566), rect: CGRect(x: 34, y: 522, width: 120, height: 34),
               tail: "M98 554l8 12 4-12z", fill: H.answer, text: "Right here, doc", ink: H.roofDark)
    }

    /// A speech bubble that grows from its tail: 0.6 → 1 as it appears, fading out in place.
    private func bubble(_ g: GraphicsContext, amount: Double, anchor: CGPoint, rect: CGRect, tail: String,
                        fill: Color, text: String, ink: Color) {
        guard amount > 0 else { return }
        g.drawLayer { c in
            c.opacity = amount
            scaled(&c, 0.6 + 0.4 * amount, at: anchor)
            c.fill(Path(roundedRect: rect, cornerRadius: rect.height / 2), with: .color(fill))
            c.fill(svg(tail), with: .color(fill))
            c.draw(Text(text).font(.system(size: 13, weight: .bold)).foregroundStyle(ink), at: CGPoint(x: rect.midX, y: rect.midY))
        }
    }

    // MARK: Drawing helpers

    private func layer(_ g: GraphicsContext, dx: Double = 0, dy: Double = 0, opacity: Double = 1, _ body: (inout GraphicsContext) -> Void) {
        g.drawLayer { c in
            c.opacity = opacity
            c.translateBy(x: dx, y: dy)
            body(&c)
        }
    }

    private func scaled(_ c: inout GraphicsContext, _ s: Double, at p: CGPoint) {
        c.translateBy(x: p.x, y: p.y); c.scaleBy(x: s, y: s); c.translateBy(x: -p.x, y: -p.y)
    }

    private func rotated(_ c: inout GraphicsContext, _ degrees: Double, at p: CGPoint) {
        c.translateBy(x: p.x, y: p.y); c.rotate(by: .degrees(degrees)); c.translateBy(x: -p.x, y: -p.y)
    }

    private func circle(_ x: CGFloat, _ y: CGFloat, _ r: CGFloat) -> Path { Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)) }
    private func ellipse(_ x: CGFloat, _ y: CGFloat, _ rx: CGFloat, _ ry: CGFloat) -> Path { Path(ellipseIn: CGRect(x: x - rx, y: y - ry, width: rx * 2, height: ry * 2)) }
    private func rounded(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ r: CGFloat) -> Path {
        Path(roundedRect: CGRect(x: x, y: y, width: w, height: h), cornerRadius: r)
    }

    /// Blends two colors (a window lighting up) instead of swapping them.
    private func mix(_ a: Color, _ b: Color, _ k: Double) -> Color {
        let ra = a.resolve(in: EnvironmentValues()), rb = b.resolve(in: EnvironmentValues())
        let f = Float(min(1, max(0, k)))
        return Color(red: Double(ra.red + (rb.red - ra.red) * f), green: Double(ra.green + (rb.green - ra.green) * f),
                     blue: Double(ra.blue + (rb.blue - ra.blue) * f))
    }

    private func svg(_ d: String) -> Path { SVGPathParser.path(d) }
}

/// Reads the handful of SVG path commands the scene uses (M L H V C S Q Z, absolute and relative),
/// so the drawing stays the design's own numbers.
private enum SVGPathParser {
    nonisolated(unsafe) private static var cache: [String: Path] = [:]

    static func path(_ d: String) -> Path {
        if let hit = cache[d] { return hit }
        let p = parse(d)
        cache[d] = p
        return p
    }

    private static func parse(_ d: String) -> Path {
        var tokens: [String] = []
        var number = ""
        for ch in d {
            if ch.isLetter && ch != "e" {
                if !number.isEmpty { tokens.append(number); number = "" }
                tokens.append(String(ch))
            } else if ch == "-" && !number.isEmpty && number.last != "e" {
                tokens.append(number); number = "-"
            } else if ch == "," || ch == " " {
                if !number.isEmpty { tokens.append(number); number = "" }
            } else {
                number.append(ch)
            }
        }
        if !number.isEmpty { tokens.append(number) }

        var path = Path()
        var i = 0
        var cmd: Character = "M"
        var cur = CGPoint.zero, startPt = CGPoint.zero, lastCtrl: CGPoint?
        func num() -> CGFloat { defer { i += 1 }; return CGFloat(Double(tokens[i]) ?? 0) }
        while i < tokens.count {
            if let c = tokens[i].first, c.isLetter { cmd = c; i += 1; if c == "Z" || c == "z" { path.closeSubpath(); cur = startPt; continue } }
            let rel = cmd.isLowercase
            let base = rel ? cur : .zero
            switch cmd.uppercased() {
            case "M":
                cur = CGPoint(x: base.x + num(), y: base.y + num()); path.move(to: cur); startPt = cur
                cmd = rel ? "l" : "L"; lastCtrl = nil
            case "L":
                cur = CGPoint(x: base.x + num(), y: base.y + num()); path.addLine(to: cur); lastCtrl = nil
            case "H":
                cur = CGPoint(x: (rel ? cur.x : 0) + num(), y: cur.y); path.addLine(to: cur); lastCtrl = nil
            case "V":
                cur = CGPoint(x: cur.x, y: (rel ? cur.y : 0) + num()); path.addLine(to: cur); lastCtrl = nil
            case "C":
                let c1 = CGPoint(x: base.x + num(), y: base.y + num()), c2 = CGPoint(x: base.x + num(), y: base.y + num())
                cur = CGPoint(x: base.x + num(), y: base.y + num()); path.addCurve(to: cur, control1: c1, control2: c2); lastCtrl = c2
            case "S":
                let c1 = lastCtrl.map { CGPoint(x: 2 * cur.x - $0.x, y: 2 * cur.y - $0.y) } ?? cur
                let c2 = CGPoint(x: base.x + num(), y: base.y + num())
                cur = CGPoint(x: base.x + num(), y: base.y + num()); path.addCurve(to: cur, control1: c1, control2: c2); lastCtrl = c2
            case "Q":
                let c1 = CGPoint(x: base.x + num(), y: base.y + num())
                cur = CGPoint(x: base.x + num(), y: base.y + num()); path.addQuadCurve(to: cur, control: c1); lastCtrl = nil
            default:
                i += 1
            }
        }
        return path
    }
}
