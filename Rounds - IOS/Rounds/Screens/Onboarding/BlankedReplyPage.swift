import SwiftUI

/* ─────────────────────────────────────────────────────────
 * ANIMATION STORYBOARD · After "Ever blanked?" (one scene per answer, young doctors with live eyes)
 *
 * ALL THE TIME   0ms   a shared thought bubble rises (600ms); its dots type (1.2s loop)
 *                loop  (8s) both doctors look up at it; at 3.5s they glance at each other,
 *                      lean in and smile; back to the bubble by 5.9s. Blinks out of step.
 * SOMETIMES      0ms   a red, racing pulse draws (900ms); the doctor is tense: eyes darting,
 *                      a frown, a small tremble, quick breaths
 *              900ms   a calm green line draws over it (900ms); the tremble fades, the smile comes
 *             2000ms   one slow, relieved blink; then the eyes follow a dot along the calm line
 * RARELY         0ms   the case card rises; History, Exam, Tests tick 400ms apart, the doctor's
 *                      eyes moving to each one
 *             1550ms   a happy squint and a small nod; then calm blinks and the odd glance at the card
 * All three      headline and line rise once the scene has played.
 * Reduce Motion: each scene's settled frame, still.
 * ───────────────────────────────────────────────────────── */

private enum TIMING {
    static let copy = 1.2
    /// Reduce Motion draws this moment: every opening beat has landed.
    static let settled = 2800.0
}

/// The scene's drawing space; the canvas scales it to fit.
private enum STAGE {
    static let size = CGSize(width: 320, height: 280)
}

private enum OFTEN {
    static let period = 8000.0
    static let aLookX: Keys = [Key(0, 1.2), Key(3000, 1.2), Key(3500, 2.6), Key(5200, 2.6), Key(5800, 1.2), Key(8000, 1.2)]
    static let aLookY: Keys = [Key(0, -2.4), Key(3000, -2.4), Key(3500, 0.4), Key(5200, 0.4), Key(5800, -2.4), Key(8000, -2.4)]
    static let bLookX: Keys = [Key(0, -1.2), Key(3100, -1.2), Key(3650, -2.6), Key(5300, -2.6), Key(5900, -1.2), Key(8000, -1.2)]
    static let bLookY: Keys = [Key(0, -2.4), Key(3100, -2.4), Key(3650, 0.4), Key(5300, 0.4), Key(5900, -2.4), Key(8000, -2.4)]
    static let aLid = blinks(period, at: [1800, 3400, 7000])
    static let bLid = blinks(period, at: [1200, 3550, 6300])
    static let aCheek: Keys = [Key(0, 0), Key(4000, 0), Key(4500, 1, out: true), Key(5100, 1), Key(5600, 0), Key(8000, 0)]
    static let bCheek: Keys = [Key(0, 0), Key(4150, 0), Key(4650, 1, out: true), Key(5200, 1), Key(5700, 0), Key(8000, 0)]
    static let aTilt: Keys = [Key(0, 0), Key(3500, 0), Key(4000, 4), Key(5200, 4), Key(5800, 0), Key(8000, 0)]
    static let bTilt: Keys = [Key(0, 0), Key(3650, 0), Key(4150, -4), Key(5300, -4), Key(5900, 0), Key(8000, 0)]
}

private enum SOMETIMES {
    static let open = 2400.0
    static let period = 7000.0
    static let openLid: Keys = [Key(0, 0), Key(1900, 0.1), Key(2050, 1), Key(2100, 1), Key(2350, 0.14, out: true)]
    static let restLid = blinks(period, at: [1400, 4600], rest: 0.14)
    static let racing: [CGFloat] = [0, -40, 40, -60, 50, -34, 30, -50, 46, -30, 20, -44, 42, -26, 24, -20, 16, -12, 0]
    static let calm: [CGPoint] = [(0, 0), (75, 0), (86, -16), (97, 18), (108, 0), (187, 0), (198, -16), (209, 18), (220, 0), (280, 0)]
        .map { CGPoint(x: 20 + $0.0, y: 236 + $0.1) }
}

private enum RARELY {
    static let rows: [(name: String, at: Double)] = [("History", 500), ("Exam", 900), ("Tests", 1300)]
    static let open = 2200.0
    static let period = 8000.0
    static let openLookX: Keys = [Key(0, 0), Key(400, 2.8), Key(open, 2.8), Key(open + 400, 0.4)]
    static let openLookY: Keys = [Key(0, 0), Key(400, -2.2), Key(800, -2.2), Key(900, -0.6), Key(1200, -0.6), Key(1300, 1.2),
                                  Key(1700, 1.2), Key(open, 0), Key(open + 400, 0)]
    static let loopLookX: Keys = [Key(0, 0.4), Key(3000, 0.4), Key(3500, 2.8), Key(4600, 2.8), Key(5100, 0.4), Key(period, 0.4)]
    static let loopLookY: Keys = [Key(0, 0), Key(3000, 0), Key(3500, -0.6), Key(4600, -0.6), Key(5100, 0), Key(period, 0)]
    static let openLid: Keys = [Key(0, 0), Key(350, 0), Key(460, 1), Key(500, 1), Key(690, 0, out: true), Key(open, 0)]
    static let loopLid = blinks(period, at: [1600, 3450, 6800])
    static let cheek: Keys = [Key(0, 0), Key(1550, 0), Key(1950, 1, out: true), Key(2800, 1), Key(3300, 0)]
    static let nod: Keys = [Key(0, 0), Key(1500, 0), Key(1750, 5), Key(2000, -1), Key(2300, 2), Key(2700, 0)]
}

/// A lid track that rests at `rest` and blinks at each time: closes in 110ms, holds 40ms, reopens
/// in 190ms (slower, easing out). The last key equals the first, so the loop never jumps.
private func blinks(_ period: Double, at times: [Double], rest: Double = 0) -> Keys {
    var keys: Keys = [Key(0, rest)]
    for b in times { keys += [Key(b, rest), Key(b + 110, 1), Key(b + 150, 1), Key(b + 340, rest, out: true)] }
    return keys + [Key(period, rest)]
}

/// The encouraging beat after "Ever blanked on something you knew?": a small scene of young doctors
/// for the student's answer and two lines. It names no settings and changes none.
struct BlankedReplyPage: View {
    var shown = true
    @AppStorage(BlankFrequency.storageKey) private var stored = ""
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var start = Date()

    private var answer: BlankFrequency { BlankFrequency(stored: stored) ?? .sometimes }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer(minLength: 0)
            TimelineView(.animation(paused: reduceMotion || !shown)) { ctx in
                let t = reduceMotion ? TIMING.settled : max(0, ctx.date.timeIntervalSince(start) * 1000)
                Canvas { g, size in
                    let k = min(size.width / STAGE.size.width, size.height / STAGE.size.height)
                    var c = g
                    c.translateBy(x: (size.width - STAGE.size.width * k) / 2, y: (size.height - STAGE.size.height * k) / 2)
                    c.scaleBy(x: k, y: k)
                    c.fill(Path(ellipseIn: CGRect(x: 35, y: 25, width: 250, height: 250)), with: .color(wash))
                    switch answer {
                    case .often: often(c, t: t)
                    case .sometimes: sometimes(c, t: t)
                    case .rarely: rarely(c, t: t)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 280)
            .accessibilityHidden(true)

            Text(answer.replyHeadline)
                .font(.system(size: 34, weight: .bold)).tracking(-0.7)
                .foregroundStyle(Theme.text)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 18)
                .rise(shown, at: TIMING.copy, offset: 8)
                .accessibilityAddTraits(.isHeader)
            Text(answer.replyLine)
                .font(.system(size: 17))
                .foregroundStyle(Theme.dim)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 10)
                .rise(shown, at: TIMING.copy + 0.15, offset: 8)
            Spacer(minLength: 0)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
        .onChange(of: shown, initial: true) { _, now in if now { start = .now } }
    }

    /// The circle behind each scene, in the color of the answer's tile on the question before.
    private var wash: Color {
        switch answer {
        case .often: Theme.cardBlue.opacity(0.12)
        case .sometimes: Theme.cardTeal.opacity(0.12)
        case .rarely: Theme.cardPurple.opacity(0.12)
        }
    }

    private func breath(_ t: Double, period: Double, phase: Double = 0, amount: CGFloat) -> CGFloat {
        reduceMotion ? 0 : amount * CGFloat(wave(t, period: period, phase: phase) + 1) / 2
    }

    // MARK: All the time: two doctors share one thought, find each other, smile

    private func often(_ g: GraphicsContext, t: Double) {
        let enter = reduceMotion ? 1 : seg(t, 0, 600)
        let lt = t.truncatingRemainder(dividingBy: OFTEN.period)
        let float = reduceMotion ? 0 : 3 * wave(t, period: 4000)
        g.drawLayer { c in
            c.opacity = enter
            c.translateBy(x: 160, y: 62 + 14 * (1 - enter) - float)
            let box = Path(roundedRect: CGRect(x: -75, y: -26, width: 150, height: 52), cornerRadius: 20)
            c.fill(box, with: .color(Theme.surface))
            c.stroke(box, with: .color(Theme.border), lineWidth: 2)
            for (i, x) in [-24.0, 0, 24].enumerated() {
                let p = reduceMotion ? 1 : loop(t - Double(i) * 150, period: 1200)
                let hop = p < 0.5 ? 7 * sin(p / 0.5 * .pi) : 0
                c.fill(Path(ellipseIn: CGRect(x: x - 6, y: -6 - hop, width: 12, height: 12)), with: .color(Theme.muted))
            }
        }
        for (x, y, r, phase) in [(132.0, 108.0, 6.0, 0.0), (122, 124, 4, 0.25)] {
            let d = reduceMotion ? 0 : wave(t, period: 6000, phase: phase)
            let ring = Path(ellipseIn: CGRect(x: x + 2 * d - r, y: y - 3 * d - r, width: r * 2, height: r * 2))
            g.drawLayer { c in
                c.opacity = enter
                c.fill(ring, with: .color(Theme.surface)); c.stroke(ring, with: .color(Theme.border), lineWidth: 2)
            }
        }
        let still = reduceMotion
        DoctorFigure.draw(g, center: CGPoint(x: 108, y: 200), size: 128, tone: Theme.cardBlue, pose: FigurePose(
            lookX: track(lt, OFTEN.aLookX), lookY: track(lt, OFTEN.aLookY), lid: still ? 0 : track(lt, OFTEN.aLid),
            cheek: track(lt, OFTEN.aCheek), smile: 0.25 + 0.5 * track(lt, OFTEN.aCheek), tilt: track(lt, OFTEN.aTilt),
            breath: breath(t, period: 3600, amount: 1.2)))
        DoctorFigure.draw(g, center: CGPoint(x: 220, y: 206), size: 116, tone: Theme.cardPink, pose: FigurePose(
            lookX: track(lt, OFTEN.bLookX), lookY: track(lt, OFTEN.bLookY), lid: still ? 0 : track(lt, OFTEN.bLid),
            cheek: track(lt, OFTEN.bCheek), smile: 0.25 + 0.5 * track(lt, OFTEN.bCheek), tilt: track(lt, OFTEN.bTilt),
            breath: breath(t, period: 4200, phase: 0.4, amount: 1.2)))
    }

    // MARK: Sometimes: a racing pulse and a tense face; the line calms, so does the face

    private func sometimes(_ g: GraphicsContext, t: Double) {
        let racing = seg(t, 0, 900, easeOut: false), calm = seg(t, 900, 1800, easeOut: false), settle = seg(t, 900, 2000)
        var jag = Path()
        jag.addLines(SOMETIMES.racing.enumerated().map { CGPoint(x: 20 + CGFloat($0.offset) * 280 / 18, y: 236 + $0.element * 0.5) })
        g.drawLayer { c in
            c.opacity = 0.7 - 0.55 * settle
            c.stroke(jag.trimmedPath(from: 0, to: racing), with: .color(Theme.wrong), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
        }
        var line = Path()
        line.addLines(SOMETIMES.calm)
        g.stroke(line.trimmedPath(from: 0, to: calm), with: .color(Theme.accent), style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))

        let after = max(0, t - SOMETIMES.open)
        let dot = point(on: SOMETIMES.calm, at: loop(after, period: 3000))
        g.drawLayer { c in
            c.opacity = seg(t, 1800, 2100)
            c.fill(Path(ellipseIn: CGRect(x: dot.x - 7, y: dot.y - 7, width: 14, height: 14)), with: .color(Theme.accent))
        }
        let tense = reduceMotion ? 0 : 1 - settle
        let lid = t < SOMETIMES.open ? track(t, SOMETIMES.openLid) : track(after.truncatingRemainder(dividingBy: SOMETIMES.period), SOMETIMES.restLid)
        let follow = (dot.x - 160) / 140 * 2.6
        DoctorFigure.draw(g, center: CGPoint(x: 160, y: 120), size: 140, tone: Theme.cardTeal, pose: FigurePose(
            lookX: tense * 1.6 * wave(t, period: 520) + (1 - tense) * follow,
            lookY: tense * -1.6 + (1 - tense) * 2.6,
            lid: lid,
            smile: -0.55 * tense + 0.45 * (1 - tense),
            breath: tense * 2 * CGFloat(wave(t, period: 420) + 1) / 2 + (1 - tense) * breath(t, period: 4000, amount: 1.4),
            dx: tense * 1.1 * wave(t, period: 90)))
    }

    /// A point a fraction of the way along a polyline, by length.
    private func point(on line: [CGPoint], at fraction: Double) -> CGPoint {
        let lengths = zip(line, line.dropFirst()).map { hypot($1.x - $0.x, $1.y - $0.y) }
        var left = lengths.reduce(0, +) * fraction
        for (i, length) in lengths.enumerated() {
            if left <= length {
                let a = line[i], b = line[i + 1], k = length == 0 ? 0 : left / length
                return CGPoint(x: a.x + (b.x - a.x) * k, y: a.y + (b.y - a.y) * k)
            }
            left -= length
        }
        return line.last ?? .zero
    }

    // MARK: Rarely: the doctor ticks each step off and nods

    private func rarely(_ g: GraphicsContext, t: Double) {
        let sway = reduceMotion ? 0 : wave(t, period: 6000)
        g.drawLayer { c in
            c.opacity = seg(t, 0, 400)
            c.translateBy(x: 222, y: 48 + 10 * (1 - seg(t, 0, 500)))
            c.rotate(by: .degrees(sway))
            let card = Path(roundedRect: CGRect(x: -66, y: 0, width: 132, height: 150), cornerRadius: 18)
            c.fill(card, with: .color(Theme.surface))
            c.stroke(card, with: .color(Theme.accent.opacity(0.3)), lineWidth: 2)
            c.fill(Path(roundedRect: CGRect(x: -28, y: -8, width: 56, height: 16), cornerRadius: 6), with: .color(Theme.accent.opacity(0.45)))
            c.draw(Text("CASE").font(.system(size: 11, weight: .heavy)).tracking(1).foregroundStyle(Theme.muted),
                   at: CGPoint(x: -50, y: 26), anchor: .leading)
            for (i, row) in RARELY.rows.enumerated() {
                let a = seg(t, row.at - 250, row.at + 100), tick = seg(t, row.at, row.at + 300)
                let y = 42 + CGFloat(i) * 34
                c.drawLayer { r in
                    r.opacity = a
                    r.translateBy(x: 0, y: 8 * (1 - a))
                    r.fill(Path(roundedRect: CGRect(x: -52, y: y, width: 104, height: 28), cornerRadius: 8), with: .color(Theme.bg))
                    r.draw(Text(row.name).font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.text),
                           at: CGPoint(x: -42, y: y + 14), anchor: .leading)
                    r.drawLayer { m in
                        m.opacity = tick
                        m.translateBy(x: 36, y: y + 14); m.scaleBy(x: 0.8 + 0.2 * tick, y: 0.8 + 0.2 * tick)
                        m.fill(Path(ellipseIn: CGRect(x: -10, y: -10, width: 20, height: 20)), with: .color(Theme.accent))
                        var check = Path()
                        check.addLines([CGPoint(x: -4, y: 0), CGPoint(x: -1, y: 3), CGPoint(x: 4, y: -3)])
                        m.stroke(check, with: .color(Theme.accentInk), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                    }
                }
            }
        }
        let inLoop = t > RARELY.open + 400
        let after = max(0, t - RARELY.open - 400).truncatingRemainder(dividingBy: RARELY.period)
        let done = seg(t, 1500, 2000)
        DoctorFigure.draw(g, center: CGPoint(x: 100, y: 196), size: 134, tone: Theme.cardPurple, pose: FigurePose(
            lookX: inLoop ? track(after, RARELY.loopLookX) : track(t, RARELY.openLookX),
            lookY: inLoop ? track(after, RARELY.loopLookY) : track(t, RARELY.openLookY),
            lid: reduceMotion ? 0 : (inLoop ? track(after, RARELY.loopLid) : track(t, RARELY.openLid)),
            cheek: reduceMotion ? 0 : track(t, RARELY.cheek),
            smile: 0.3 + 0.5 * done,
            tilt: reduceMotion ? 0 : track(t, RARELY.nod),
            breath: breath(t, period: 3800, amount: 1.3)))
    }
}
